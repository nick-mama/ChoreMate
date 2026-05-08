const admin = require("firebase-admin");

const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const householdId = "npKq0VBNMjIeumuhYTnV";

const members = [
  {
    uid: "USER_UID_1",
    name: "Hillary",
  },
  {
    uid: "USER_UID_2",
    name: "Garrett",
  },
  {
    uid: "Rl4hnvOEGoQMWC0O8Df8JLyrjsY2",
    name: "Geoffrey",
  },
  {
    uid: "USER_UID_4",
    name: "Nick",
  },
];

const chores = [
  {
    name: "Laundry",
    description: "Wash, dry, and fold clothes.",
    dueDate: new Date("2026-05-10T12:00:00"),
    estimatedTime: "1 hour",
    assignedTo: members[2],
    recurring: true,
    completed: false,
  },
  {
    name: "Dishwashing",
    description: "Wash dishes and wipe kitchen counters.",
    dueDate: new Date("2026-05-10T12:00:00"),
    estimatedTime: "45 min",
    assignedTo: members[0],
    recurring: true,
    completed: false,
  },
  {
    name: "Trash",
    description: "Take out trash and replace liners.",
    dueDate: new Date("2026-05-11T12:00:00"),
    estimatedTime: "15 min",
    assignedTo: members[1],
    recurring: true,
    completed: false,
  },
  {
    name: "Vacuuming",
    description: "Vacuum common areas and hallway.",
    dueDate: new Date("2026-05-08T12:00:00"),
    estimatedTime: "30 min",
    assignedTo: members[3],
    recurring: true,
    completed: true,
    completedAt: new Date("2026-05-08T15:22:00"),
  },
  {
    name: "Dusting",
    description: "Dust shelves, tables, and TV stand.",
    dueDate: new Date("2026-05-09T12:00:00"),
    estimatedTime: "25 min",
    assignedTo: members[2],
    recurring: true,
    completed: true,
    completedAt: new Date("2026-05-08T17:13:00"),
  },
];

async function clearChores() {
  const snapshot = await db
    .collection("chores")
    .where("householdId", "==", householdId)
    .get();

  if (snapshot.empty) {
    console.log("No chores to delete.");
    return;
  }

  const batchSize = 400;
  let batch = db.batch();
  let count = 0;

  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
    count++;

    if (count % batchSize === 0) {
      await batch.commit();
      batch = db.batch();
    }
  }

  await batch.commit();

  console.log(`Deleted ${count} existing chores.`);
}

async function seedChores() {
  await clearChores();

  const batch = db.batch();

  chores.forEach((chore) => {
    const docRef = db.collection("chores").doc();

    batch.set(docRef, {
      householdId,
      name: chore.name,
      description: chore.description,
      dueDate: admin.firestore.Timestamp.fromDate(chore.dueDate),
      estimatedTime: chore.estimatedTime,
      assignedTo: chore.assignedTo.uid,
      assignedToName: chore.assignedTo.name,
      recurring: chore.recurring,
      completed: chore.completed,
      completedAt: chore.completedAt
        ? admin.firestore.Timestamp.fromDate(chore.completedAt)
        : null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  await batch.commit();

  console.log(`Seeded ${chores.length} chores.`);
}

seedChores()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Seed failed:", error);
    process.exit(1);
  });