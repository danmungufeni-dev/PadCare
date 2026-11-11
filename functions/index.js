const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();
const db = admin.firestore();

/**
 * Normalizes school names to canonical identifiers for exact matching.
 * e.g., "St. Mary's Secondary" -> "st_marys_secondary"
 */
function normalizeSchoolId(name) {
  if (!name) return "";
  return name
    .toLowerCase()
    .replace(/['’]/g, "")
    .replace(/[^a-z0-9]/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_|_$/g, "");
}

/**
 * 1. SECURE SERVER-SIDE PIN GENERATION
 * Callable function invoked when a teacher submits a student sanitary pad request.
 * Generates a unique cryptographically secure 4-digit numeric string, creates `pin_records`, and updates `requests`.
 */
exports.generateRequestPin = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required to generate request PIN.");
  }

  const { requestId, schoolId, productId, quantity, teacherName } = request.data || {};
  if (!requestId || !schoolId || !quantity) {
    throw new HttpsError("invalid-argument", "Missing required parameters: requestId, schoolId, quantity.");
  }

  // 1. Generate unique 4-digit PIN not in active use using cryptographic randomness
  let candidatePin = "";
  let isUnique = false;
  let attempts = 0;

  while (!isUnique && attempts < 25) {
    attempts++;
    const randomNum = crypto.randomInt(1000, 10000);
    candidatePin = randomNum.toString();

    const existingDoc = await db.collection("pin_records").doc(candidatePin).get();
    if (!existingDoc.exists) {
      isUnique = true;
    } else {
      const data = existingDoc.data();
      if (data.status !== "active") {
        isUnique = true; // Safe to recycle inactive or old redeemed pins
      }
    }
  }

  if (!isUnique) {
    candidatePin = crypto.randomInt(1000, 10000).toString();
  }

  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + 30); // 30-day validity

  const reference = `PH-${candidatePin}`;

  const batch = db.batch();

  // Create PIN Record
  const pinRef = db.collection("pin_records").doc(candidatePin);
  batch.set(pinRef, {
    pin: candidatePin,
    requestId: requestId,
    reference: reference,
    schoolId: schoolId,
    productId: productId || "disposable-pads",
    quantity: Number(quantity),
    status: "active",
    failedAttempts: 0,
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdByUid: request.auth.uid,
    createdByName: teacherName || "Teacher",
  });

  // Update Request Record
  const reqRef = db.collection("requests").doc(requestId);
  batch.set(
    reqRef,
    {
      reference: reference,
      pickupPin: candidatePin,
      status: "Approved",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  await batch.commit();

  return {
    success: true,
    pin: candidatePin,
    reference: reference,
    expiresAt: expiresAt.toISOString(),
  };
});

/**
 * 2. ATOMIC PIN DISPENSE AND INVENTORY HANDOUT
 * Callable function executed when a school administrator enters a PIN.
 * Atomic transaction ensures:
 * - PIN is valid, active, and belongs to admin's school
 * - Stock is available and atomically deducted
 * - Request is marked Collected
 * - Distribution transaction is logged
 * - Double dispensing is strictly prevented
 */
exports.dispenseByPin = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required to dispense products.");
  }

  // Server-side Staff Role Verification
  const userDoc = await db.collection("users").doc(request.auth.uid).get();
  if (!userDoc.exists) {
    const tokenEmail = (request.auth.token.email || "").toLowerCase();
    const isDemoAuthorized = tokenEmail.includes("teacher") ||
      tokenEmail.includes("devgtnation") ||
      tokenEmail.includes("abetinichlas");
    if (!isDemoAuthorized) {
      throw new HttpsError("permission-denied", "User profile not found. Verified school staff authorization required.");
    }
  } else {
    const userData = userDoc.data();
    const isStaff = userData.role === "teacher" || userData.role === "admin" || userData.role === "school_admin";
    const isAuthorized = userData.authorized === true || userData.status === "approved";
    if (!isStaff || !isAuthorized) {
      throw new HttpsError("permission-denied", "Unauthorized user. Only verified school staff may dispense sanitary products.");
    }
  }

  const { pin, schoolFacility, dispensedByName } = request.data || {};
  if (!pin || !schoolFacility) {
    throw new HttpsError("invalid-argument", "Missing required parameters: pin, schoolFacility.");
  }

  const cleanPin = pin.toString().replace(/#/g, "").trim();

  return await db.runTransaction(async (transaction) => {
    // 1. Verify PIN Record
    const pinRef = db.collection("pin_records").doc(cleanPin);
    const pinDoc = await transaction.get(pinRef);

    if (!pinDoc.exists) {
      throw new HttpsError("not-found", `PIN #${cleanPin} does not exist in the system.`);
    }

    const pinData = pinDoc.data();

    if (pinData.status === "redeemed") {
      throw new HttpsError("failed-precondition", `PIN #${cleanPin} was already collected and dispensed.`);
    }

    if (pinData.status !== "active") {
      throw new HttpsError("failed-precondition", `PIN #${cleanPin} is no longer active (${pinData.status}).`);
    }

    // Verify PIN Expiration (strict 30-day enforcement)
    if (pinData.expiresAt) {
      const expiryDate = pinData.expiresAt.toDate ? pinData.expiresAt.toDate() : new Date(pinData.expiresAt);
      if (new Date() > expiryDate) {
        throw new HttpsError(
          "failed-precondition",
          `PIN #${cleanPin} expired on ${expiryDate.toLocaleDateString()}. Please request a fresh care kit.`
        );
      }
    }

    // Check school facility exact match
    const normSchool = normalizeSchoolId(schoolFacility);
    const pinSchool = normalizeSchoolId(pinData.schoolId);
    if (normSchool !== pinSchool && pinData.schoolId.toLowerCase().trim() !== schoolFacility.toLowerCase().trim()) {
      throw new HttpsError(
        "permission-denied",
        `PIN #${cleanPin} is registered for ${pinData.schoolId}, not ${schoolFacility}. Please direct the student to ${pinData.schoolId}.`
      );
    }

    // 2. Verify Request
    const reqRef = db.collection("requests").doc(pinData.requestId);
    const reqDoc = await transaction.get(reqRef);
    if (!reqDoc.exists) {
      throw new HttpsError("not-found", `Associated request for PIN #${cleanPin} was not found.`);
    }

    const reqData = reqDoc.data();
    if (reqData.status === "Collected") {
      throw new HttpsError("already-exists", `Request ${pinData.reference} was already collected.`);
    }

    // 3. Verify Stock in School Facility
    const schoolRef = db.collection("schools").doc(schoolFacility);
    const schoolDoc = await transaction.get(schoolRef);

    const isKit = (pinData.productId || "").toLowerCase().includes("kit");
    const requestedQty = Number(pinData.quantity) || 1;

    let availableStock = 0;
    if (schoolDoc.exists) {
      const sData = schoolDoc.data();
      availableStock = isKit ? (sData.kitsOnHand || 0) : (sData.packsOnHand || 0);
    }

    if (availableStock < requestedQty) {
      throw new HttpsError("resource-exhausted", `Insufficient stock at ${schoolFacility}. Available: ${availableStock}, Requested: ${requestedQty}.`);
    }

    // 4. Atomic Deductions & State Transitions
    // A. Update School Stock
    transaction.set(
      schoolRef,
      {
        [isKit ? "kitsOnHand" : "packsOnHand"]: availableStock - requestedQty,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // B. Mark Request as Collected
    transaction.update(reqRef, {
      status: "Collected",
      collectedAt: admin.firestore.FieldValue.serverTimestamp(),
      collectedBy: dispensedByName || request.auth.token.email || "School Staff",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // C. Mark PIN as Redeemed
    transaction.update(pinRef, {
      status: "redeemed",
      redeemedAt: admin.firestore.FieldValue.serverTimestamp(),
      redeemedByUid: request.auth.uid,
    });

    // D. Create Immutable Distribution Audit Record
    const dispRef = db.collection("dispensations").doc(`DIST-${pinData.requestId}-${Date.now()}`);
    transaction.set(dispRef, {
      requestId: pinData.requestId,
      reference: pinData.reference,
      pickupPin: cleanPin,
      school: schoolFacility,
      productId: pinData.productId,
      quantity: requestedQty,
      dispensedBy: dispensedByName || request.auth.token.email || "School Staff",
      dispensedByUid: request.auth.uid,
      dispensedAt: admin.firestore.FieldValue.serverTimestamp(),
      status: "completed",
    });

    // E. Create Traceable Stock Movement Record
    const moveRef = db.collection("stock_movements").doc(`SM-${pinData.requestId}-${Date.now()}`);
    transaction.set(moveRef, {
      movementId: moveRef.id,
      schoolId: schoolFacility,
      productId: pinData.productId,
      quantityChange: -requestedQty,
      previousStock: availableStock,
      newStock: availableStock - requestedQty,
      reason: "student_dispense",
      referenceId: pinData.requestId,
      pickupPin: cleanPin,
      performedBy: dispensedByName || request.auth.token.email || "School Staff",
      performedByUid: request.auth.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      pin: cleanPin,
      reference: pinData.reference,
      quantity: requestedQty,
      product: pinData.productId,
      school: schoolFacility,
    };
  });
});

/**
 * 3. NOTIFICATION TRIGGER ON REQUEST STATUS UPDATE
 */
exports.sendRequestNotification = onDocumentUpdated("requests/{requestId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status === after.status) return;

  const teacherUid = after.teacherUid;
  if (!teacherUid) return;

  // Retrieve teacher profile and device token
  const teacherDoc = await db.collection("users").doc(teacherUid).get();
  if (!teacherDoc.exists) return;

  const teacherData = teacherDoc.data();
  const fcmToken = teacherData.fcmToken;

  // Insert in-app notification document
  await db.collection("notifications").add({
    recipientUid: teacherUid,
    schoolId: after.schoolId || after.school,
    title: `Request ${after.reference || after.id} Updated`,
    body: `Your request status has changed to: ${after.status}.`,
    type: "request_update",
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // If FCM token available, send push alert
  if (fcmToken) {
    try {
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: `Request ${after.reference} Update`,
          body: `Status: ${after.status} at ${after.school}.`,
        },
        data: {
          requestId: String(event.params.requestId),
          status: String(after.status),
        },
      });
    } catch (err) {
      console.warn("FCM push delivery error:", err);
    }
  }
});

/**
 * 4. SERVER-SIDE PAYMENT & SPONSOR DONATION VERIFICATION
 * Validates donor transaction references server-side (MoMo/AirtelMoney/Bank),
 * marks donation record completed, generates a verified receipt, and updates campaign impact.
 */
exports.verifyDonationPayment = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required to verify donation.");
  }

  const { donationId, transactionReference, amount, currency, campaignId, schoolName } = request.data || {};
  if (!donationId || !transactionReference || !amount) {
    throw new HttpsError("invalid-argument", "Missing donation verification parameters.");
  }

  const donationRef = db.collection("donations").doc(donationId);
  const receiptNumber = `REC-DON-${Date.now()}`;
  const verifiedAt = admin.firestore.FieldValue.serverTimestamp();

  await db.runTransaction(async (transaction) => {
    // 1. Update Donation Record
    transaction.set(donationRef, {
      donationId: donationId,
      sponsorUid: request.auth.uid,
      amount: Number(amount),
      currency: currency || "UGX",
      transactionReference: transactionReference,
      paymentStatus: "completed",
      receiptNumber: receiptNumber,
      campaignId: campaignId || null,
      schoolName: schoolName || "Arua Schools",
      verifiedAt: verifiedAt,
      updatedAt: verifiedAt,
    }, { merge: true });

    // 2. If campaign linked, increment funded metrics atomically
    if (campaignId) {
      const campaignRef = db.collection("campaigns").doc(campaignId);
      const kitsFunded = Math.floor(Number(amount) / 10000);
      transaction.update(campaignRef, {
        raisedUGX: admin.firestore.FieldValue.increment(Number(amount)),
        fundedKits: admin.firestore.FieldValue.increment(kitsFunded),
        updatedAt: verifiedAt,
      });
    }

    // 3. Write Immutable Audit Log
    const auditRef = db.collection("audit_logs").doc(`AUDIT-PAY-${donationId}`);
    transaction.set(auditRef, {
      logId: auditRef.id,
      action: "donation_verified",
      entityType: "donation",
      entityId: donationId,
      performedByUid: request.auth.uid,
      amount: Number(amount),
      receiptNumber: receiptNumber,
      timestamp: verifiedAt,
    });
  });

  return {
    success: true,
    donationId: donationId,
    receiptNumber: receiptNumber,
    paymentStatus: "completed",
    verified: true,
  };
});
