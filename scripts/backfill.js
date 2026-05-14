const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function backfillRoles() {
  const householdsSnap = await db.collection("households").get();

  for (const householdDoc of householdsSnap.docs) {
    const householdId = householdDoc.id;
    const household = householdDoc.data();

    const ownerId =
      household.ownerId ||
      household.createdBy ||
      household.createdByUserId ||
      household.members?.[0];

    const updates = {};

    if (!household.householdType) {
      updates.householdType = "roommates";
    }

    if (ownerId && !household.ownerId) {
      updates.ownerId = ownerId;
    }

    if (Object.keys(updates).length > 0) {
      await householdDoc.ref.update(updates);
    }

    const members = household.members || [];

    for (const uid of members) {
      await householdDoc.ref.collection("members").doc(uid).set(
        {
          userId: uid,
          role: uid === ownerId ? "owner" : "member",
          joinedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    console.log(`Backfilled ${householdId}`);
  }
}

backfillRoles()
  .then(() => {
    console.log("Done");
    process.exit(0);
  })
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });