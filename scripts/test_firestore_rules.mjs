import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import {
  doc,
  getDoc,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteField,
  arrayUnion,
  getDocs,
  orderBy,
  query,
} from 'firebase/firestore';

const projectId = 'demo-mathquest-rules';
const studentId = 'game-mode-student';
const secondStudentId = 'existing-entry-student';
const attackerId = 'unrelated-student';
const legacyProgressId = 'legacy-progress-student';
const teacherId = 'approved-teacher';
const pendingStudentId = 'pending-student';
const existingProgressStudentId = 'existing-progress-student';
const maxProgressStudentId = 'max-progress-student';
const legacyLeaderboardStudentId = 'legacy-leaderboard-student';
const missingScoreFieldsStudentId = 'missing-score-fields-student';
const stringLevelProgressStudentId = 'string-level-progress-student';
const levelQuestionAwardStudentId = 'level-question-award-student';
const npcProgressStudentId = 'npc-progress-student';
const noSessionStudentId = 'no-active-session-student';
const sequentialNpcStudentId = 'sequential-npc-student';
const legacyStringScoreStudentId = 'legacy-string-score-student';
const newClassroomCompletionStudentId = 'new-classroom-completion-student';
const rejectedClassroomCompletionStudentId =
  'rejected-classroom-completion-student';
const profileEditStudentId = 'profile-edit-student';
const occupiedLrnStudentId = 'occupied-lrn-student';
const pendingProfileStudentId = 'pending-profile-student';
const rejectedProfileStudentId = 'rejected-profile-student';
const originalProfileLrn = '123456789012';
const updatedProfileLrn = '234567890123';
const occupiedProfileLrn = '345678901234';
const occupiedOldLrn = '456789012345';
const questions = [1, 2, 3, 4, 5, 6];
const timestamp = Timestamp.fromDate(new Date('2026-01-01T00:00:00Z'));
const rules = await readFile(
  fileURLToPath(new URL('../firestore.rules', import.meta.url)),
  'utf8',
);
const testEnv = await initializeTestEnvironment({
  projectId,
  firestore: { rules },
});

function student(uid) {
  return {
    uid,
    email: `${uid}@example.test`,
    name: uid,
    role: 'student',
    status: 'approved',
    lrn: '123456789012',
    createdAt: timestamp,
    scoreBaseline: 0,
    scoreEarned: 0,
    gameScore: 0,
    progress: {
      completedLevels: [],
      completedNpcQuestions: questions,
      completedNpcQuestionsByLevel: { '1': questions },
      unlockedLevels: 1,
      maxUnlockedSubLevel: { '1': 1, '2': 1, '3': 1 },
      gameModeFinalScores: {},
    },
  };
}

async function seedStudent(uid, leaderboardScore) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users', uid), student(uid));
    await setDoc(doc(db, 'activeSessions', uid), { sessionId: 'active' });
    if (leaderboardScore != null) {
      await setDoc(doc(db, 'leaderboard', uid), {
        uid,
        displayName: uid,
        totalScore: leaderboardScore,
        createdAt: timestamp,
        updatedAt: timestamp,
      });
    }
  });
}

async function seedStudentWithoutSession(uid) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users', uid), student(uid));
  });
}

async function seedTeacher(uid) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users', uid), {
      uid,
      name: uid,
      role: 'teacher',
      status: 'approved',
    });
    await setDoc(doc(db, 'activeSessions', uid), { sessionId: 'active' });
  });
}

async function completeGameMode(uid, score, level = 1) {
  const db = testEnv.authenticatedContext(uid).firestore();
  const userRef = doc(db, 'users', uid);
  const leaderboardRef = doc(db, 'leaderboard', uid);
  const awardRef = doc(userRef, 'scoreAwards', `game-mode-${level}`);

  await runTransaction(db, async (transaction) => {
    const userSnapshot = await transaction.get(userRef);
    const leaderboardSnapshot = await transaction.get(leaderboardRef);
    const awardSnapshot = await transaction.get(awardRef);
    const userData = userSnapshot.data();
    const oldScore = userData.progress.gameModeFinalScores[String(level)];
    if (oldScore != null) {
      assert.equal(oldScore, score);
      return;
    }
    assert.equal(awardSnapshot.exists(), false);

    const oldEarned = userData.scoreEarned ?? 0;
    const oldProgress = userData.progress;
    const leaderboardRecord = leaderboardSnapshot.data() ?? {};
    const rawPreviousLeaderboardScore =
      leaderboardRecord.totalScore ?? leaderboardRecord.totalscore ?? 0;
    const previousLeaderboardScore =
      typeof rawPreviousLeaderboardScore === 'number'
        ? rawPreviousLeaderboardScore
        : Number.parseInt(rawPreviousLeaderboardScore, 10);
    assert.ok(
      Number.isSafeInteger(previousLeaderboardScore)
        && previousLeaderboardScore >= 0,
    );
    const completedLevels = arrayUnion(level);
    const mainLevel = Math.floor((level - 1) / 20) + 1;
    const displayNumber = level % 20 === 0 ? 20 : level % 20;
    const nextSubLevel = displayNumber + 1;
    const sublevels = {
      ...(oldProgress.maxUnlockedSubLevel ?? { '1': 1, '2': 1, '3': 1 }),
    };
    if (nextSubLevel <= 20 && nextSubLevel > (sublevels[mainLevel] ?? 1)) {
      sublevels[mainLevel] = nextSubLevel;
    }
    transaction.update(userRef, {
      'progress.completedLevels': completedLevels,
      'progress.unlockedLevels': oldProgress.unlockedLevels ?? 1,
      'progress.maxUnlockedSubLevel': {
        '1': sublevels['1'] ?? 1,
        '2': sublevels['2'] ?? 1,
        '3': sublevels['3'] ?? 1,
      },
      [`progress.gameModeFinalScores.${level}`]: score,
      'progress.latestCompletedGameModeLevel': String(level),
      scoreEarned: oldEarned + score,
      gameScore: (userData.scoreBaseline ?? 0) + oldEarned + score,
    });
    transaction.set(awardRef, {
      points: score,
      createdAt: serverTimestamp(),
    });
    const leaderboardData = {
      uid,
      displayName: uid,
      totalScore: previousLeaderboardScore + score,
      createdAt: timestamp,
      updatedAt: serverTimestamp(),
    };
    if (leaderboardSnapshot.exists()) {
      const existingLeaderboard = leaderboardSnapshot.data();
      if (Object.hasOwn(existingLeaderboard, 'displayname')) {
        leaderboardData.displayname = deleteField();
      }
      if (Object.hasOwn(existingLeaderboard, 'name')) {
        leaderboardData.name = deleteField();
      }
      if (Object.hasOwn(existingLeaderboard, 'totalscore')) {
        leaderboardData.totalscore = deleteField();
      }
      transaction.update(leaderboardRef, leaderboardData);
    } else {
      transaction.set(leaderboardRef, leaderboardData);
    }
  });
}

async function awardLevelQuestionPoints(uid, level) {
  const db = testEnv.authenticatedContext(uid).firestore();
  const userRef = doc(db, 'users', uid);
  const leaderboardRef = doc(db, 'leaderboard', uid);
  const awardRef = doc(userRef, 'scoreAwards', String(level));

  await runTransaction(db, async (transaction) => {
    const userSnapshot = await transaction.get(userRef);
    const leaderboardSnapshot = await transaction.get(leaderboardRef);
    const awardSnapshot = await transaction.get(awardRef);
    if (awardSnapshot.exists()) {
      assert.equal(awardSnapshot.data().points, 10);
      return;
    }

    const progress = userSnapshot.data().progress;
    assert.ok(progress.levelQuestionAnswers[String(level)]);
    const existing = leaderboardSnapshot.data();
    assert.ok(existing);
    transaction.set(awardRef, {
      points: 10,
      createdAt: serverTimestamp(),
    });
    transaction.update(leaderboardRef, {
      totalScore: existing.totalScore + 10,
      updatedAt: serverTimestamp(),
    });
  });
}

async function awardMissionPoints(uid, points, awardId) {
  const db = testEnv.authenticatedContext(uid).firestore();
  const userRef = doc(db, 'users', uid);
  const leaderboardRef = doc(db, 'leaderboard', uid);
  const awardRef = doc(userRef, 'scoreAwards', `mission-${awardId}`);

  await runTransaction(db, async (transaction) => {
    const userSnapshot = await transaction.get(userRef);
    const leaderboardSnapshot = await transaction.get(leaderboardRef);
    const awardSnapshot = await transaction.get(awardRef);
    if (awardSnapshot.exists()) {
      assert.equal(awardSnapshot.data().points, points);
      return;
    }

    assert.ok(userSnapshot.exists());
    const existing = leaderboardSnapshot.data();
    assert.ok(existing);
    transaction.set(awardRef, {
      points,
      createdAt: serverTimestamp(),
    });
    transaction.update(leaderboardRef, {
      totalScore: existing.totalScore + points,
      updatedAt: serverTimestamp(),
    });
  });
}

async function completeNpcQuestion(uid, questionNumber, level = 1) {
  const db = testEnv.authenticatedContext(uid).firestore();
  const userRef = doc(db, 'users', uid);

  await runTransaction(db, async (transaction) => {
    const snapshot = await transaction.get(userRef);
    const progress = snapshot.data().progress;
    const byLevel = progress.completedNpcQuestionsByLevel ?? {};
    const completed = byLevel[String(level)] ?? [];
    if (completed.includes(questionNumber)) return;
    assert.equal(completed.length + 1, questionNumber);

    const updatedQuestions = [...completed, questionNumber];
    transaction.set(
      userRef,
      {
        progress: {
          completedNpcQuestions: level === 1
            ? updatedQuestions
            : progress.completedNpcQuestions,
          completedNpcQuestionsByLevel: {
            ...byLevel,
            [String(level)]: updatedQuestions,
          },
          latestCompletedNpcQuestionLevel: String(level),
        },
      },
      { merge: true },
    );
  });
}

async function saveGameModeAnswers(uid) {
  const db = testEnv.authenticatedContext(uid).firestore();
  for (let questionNumber = 1; questionNumber <= 6; questionNumber++) {
    await setDoc(
      doc(db, 'users', uid, 'gameModeAttempts', `level-1-${questionNumber}`),
      {
        uid,
        level: 1,
        questionNumber,
        question: `Question ${questionNumber}`,
        selectedAnswer: '2',
        correctAnswer: '2',
        isCorrect: true,
        scoreEarned: 10,
        scoreAfter: questionNumber * 10,
        attemptedAt: serverTimestamp(),
      },
    );
  }
}

async function recordClassroomAttempt(uid, attemptId, questionNumber = 1) {
  const db = testEnv.authenticatedContext(uid).firestore();
  const userRef = doc(db, 'users', uid);
  const attemptRef = doc(userRef, 'classroomQuestAttempts', attemptId);
  await runTransaction(db, async (transaction) => {
    const userSnapshot = await transaction.get(userRef);
    const attemptSnapshot = await transaction.get(attemptRef);
    if (attemptSnapshot.exists()) return;
    const userData = userSnapshot.data();
    const oldCount = userData.progress.questAttempts ?? 0;
    transaction.set(attemptRef, {
      uid,
      questId: 'classroom_quest',
      type: 'answer',
      questionNumber,
      answer: '3/4',
      isCorrect: true,
      score: 10,
      attemptNumber: oldCount + 1,
      timeSpentSeconds: 12,
      timedOut: false,
      status: 'correct',
      attemptedAt: serverTimestamp(),
    });
    transaction.update(userRef, {
      'progress.questAttempts': oldCount + 1,
      'progress.latestClassroomQuestAttemptId': attemptId,
    });
  });
}

async function completeClassroomQuest(
  uid,
  completionTimeSeconds,
  {
    correctAnswers = 3,
    totalQuestions = 3,
    recordAttempts = true,
  } = {},
) {
  const db = testEnv.authenticatedContext(uid).firestore();
  const userRef = doc(db, 'users', uid);
  const dayKey = classroomQuestDayKey();
  const dailyRef = doc(userRef, 'classroomQuestDailyCompletions', dayKey);
  const completionId = `classroom-completion-${uid}`;
  const correctAttemptIds = [1, 2, 3].map(
    (questionNumber) => `${completionId}-answer-${questionNumber}`,
  );
  const questionIds = ['worksheet-1', 'worksheet-2', 'worksheet-3'];
  if (recordAttempts) {
    for (let questionNumber = 1; questionNumber <= 3; questionNumber++) {
      await recordClassroomAttempt(
        uid,
        correctAttemptIds[questionNumber - 1],
        questionNumber,
      );
    }
  }
  await runTransaction(db, async (transaction) => {
    const snapshot = await transaction.get(userRef);
    const dailySnapshot = await transaction.get(dailyRef);
    if (dailySnapshot.exists()) return;
    const progress = snapshot.data().progress ?? {};
    const results = { ...(progress.classroomQuestResults ?? {}) };
    const history = { ...(progress.classroomQuestHistory ?? {}) };
    const completionTimes = {
      ...(progress.classroomQuestCompletionTimes ?? {}),
      classroom_quest: completionTimeSeconds,
    };
    const completedAt = serverTimestamp();
    history[completionId] = {
      type: 'completion',
      completionTimeSeconds,
      score: correctAnswers * 10,
      correctAnswers,
      totalQuestions,
      dayKey,
      completedAt,
    };
    results.classroom_quest = {
      status: 'completed',
      completionTimeSeconds,
      score: correctAnswers * 10,
      correctAnswers,
      totalQuestions,
      dayKey,
      completedAt,
    };
    transaction.update(userRef, {
      'progress.classroomQuestCompletionTimes': completionTimes,
      'progress.classroomQuestResults': results,
      'progress.classroomQuestHistory': history,
      'progress.latestClassroomQuestHistoryId': completionId,
    });
    transaction.set(dailyRef, {
      uid,
      questId: 'classroom_quest',
      dayKey,
      completionId,
      questionIds,
      correctAttemptIds,
      completionTimeSeconds,
      correctAnswers,
      totalQuestions,
      score: correctAnswers * 10,
      completedAt,
    });
  });
}

function classroomQuestDayKey(date = new Date()) {
  const manilaDate = new Date(date.getTime() + 8 * 60 * 60 * 1000);
  return `${manilaDate.getUTCFullYear()}-${String(
    manilaDate.getUTCMonth() + 1,
  ).padStart(2, '0')}-${String(manilaDate.getUTCDate()).padStart(2, '0')}`;
}

try {
  await seedStudent(studentId, null);
  await seedStudent(secondStudentId, 35);
  await seedStudent(attackerId, 0);
  await seedStudent(legacyProgressId, null);
  await seedStudent(pendingStudentId, null);
  await seedStudent(existingProgressStudentId, 155);
  await seedStudent(maxProgressStudentId, 3565);
  await seedStudent(legacyLeaderboardStudentId, null);
  await seedStudent(missingScoreFieldsStudentId, null);
  await seedStudent(stringLevelProgressStudentId, 130);
  await seedStudent(levelQuestionAwardStudentId, null);
  await seedStudent(npcProgressStudentId, null);
  await seedStudent(sequentialNpcStudentId, null);
  await seedStudent(legacyStringScoreStudentId, null);
  await seedStudent(newClassroomCompletionStudentId, null);
  await seedStudent(rejectedClassroomCompletionStudentId, null);
  await seedStudent(profileEditStudentId, null);
  await seedStudent(occupiedLrnStudentId, null);
  await seedStudent(pendingProfileStudentId, null);
  await seedStudent(rejectedProfileStudentId, null);
  await seedStudent('legacy-profile-student', null);
  await seedStudentWithoutSession(noSessionStudentId);
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await updateDoc(doc(db, 'users', 'legacy-profile-student'), {
      address: deleteField(),
      grade: deleteField(),
    });
    await updateDoc(doc(db, 'users', pendingProfileStudentId), {
      status: 'pending',
    });
    await updateDoc(doc(db, 'users', rejectedProfileStudentId), {
      status: 'rejected',
    });
    await setDoc(doc(db, 'lrnIndexes', originalProfileLrn), {
      uid: profileEditStudentId,
      createdAt: timestamp,
    });
    await setDoc(doc(db, 'lrnIndexes', occupiedProfileLrn), {
      uid: occupiedLrnStudentId,
      createdAt: timestamp,
    });
    await updateDoc(doc(db, 'users', occupiedLrnStudentId), {
      lrn: occupiedOldLrn,
    });
    await setDoc(doc(db, 'lrnIndexes', occupiedOldLrn), {
      uid: occupiedLrnStudentId,
      createdAt: timestamp,
    });
    await setDoc(
      doc(db, 'leaderboard', legacyStringScoreStudentId),
      {
        uid: legacyStringScoreStudentId,
        displayname: legacyStringScoreStudentId,
        totalscore: '75',
        createdAt: timestamp,
        updatedAt: timestamp,
      },
    );
  });
  {
    const db = testEnv.authenticatedContext(profileEditStudentId).firestore();
    const userRef = doc(db, 'users', profileEditStudentId);
    await assertSucceeds(updateDoc(userRef, { name: 'Updated Name' }));
    await assertSucceeds(updateDoc(userRef, { address: 'Updated address' }));
    await assertSucceeds(updateDoc(userRef, { grade: 'Grade 7' }));
    await assertFails(updateDoc(userRef, { address: deleteField() }));
    await assertFails(updateDoc(userRef, { grade: deleteField() }));
    await assertFails(updateDoc(userRef, { grade: 'Grade 8' }));
    await assertFails(updateDoc(userRef, { email: 'forged@example.test' }));
    const unverifiedEmailDb = testEnv.authenticatedContext(
      profileEditStudentId,
      {
        email: 'unverified@example.test',
        email_verified: false,
      },
    ).firestore();
    await assertFails(updateDoc(
      doc(unverifiedEmailDb, 'users', profileEditStudentId),
      { email: 'unverified@example.test' },
    ));
    const attackerDb = testEnv.authenticatedContext(attackerId).firestore();
    await assertFails(updateDoc(
      doc(attackerDb, 'users', profileEditStudentId),
      { name: 'Unauthorized Name' },
    ));

    await assertSucceeds(runTransaction(db, async (transaction) => {
      const currentIndex = doc(db, 'lrnIndexes', originalProfileLrn);
      const nextIndex = doc(db, 'lrnIndexes', updatedProfileLrn);
      const [profile, oldIndex, newIndex] = await Promise.all([
        transaction.get(userRef),
        transaction.get(currentIndex),
        transaction.get(nextIndex),
      ]);
      assert.equal(profile.data().lrn, originalProfileLrn);
      assert.equal(oldIndex.data().uid, profileEditStudentId);
      assert.equal(newIndex.exists(), false);
      transaction.update(userRef, {
        lrn: updatedProfileLrn,
        name: 'LRN Transaction Name',
      });
      transaction.set(nextIndex, {
        uid: profileEditStudentId,
        createdAt: serverTimestamp(),
      });
      transaction.delete(currentIndex);
    }));

    const updatedEmail = 'verified@example.test';
    const emailDb = testEnv.authenticatedContext(profileEditStudentId, {
      email: updatedEmail,
      email_verified: true,
    }).firestore();
    await assertSucceeds(updateDoc(
      doc(emailDb, 'users', profileEditStudentId),
      { email: updatedEmail },
    ));
    const photoDb = db;
    await assertSucceeds(runTransaction(photoDb, async (transaction) => {
      const currentUser = await transaction.get(userRef);
      transaction.update(userRef, {
        profilePhotoUrl: 'firestore://profile-photo',
      });
      transaction.set(doc(userRef, 'profileData', 'photo'), {
        data: 'data:image/jpeg;base64,YWJj',
      });
      assert.equal(currentUser.exists(), true);
    }));
    const photoRef = doc(userRef, 'profileData', 'photo');
    const replacementBatch = writeBatch(photoDb);
    replacementBatch.update(userRef, {
      profilePhotoUrl: 'firestore://profile-photo',
    });
    replacementBatch.set(photoRef, {
      data: 'data:image/png;base64,UkVQTEFDRU1FTlQ=',
    });
    await assertFails(replacementBatch.commit());
    assert.equal(
      (await getDoc(photoRef)).data().data,
      'data:image/jpeg;base64,YWJj',
    );

    await assertSucceeds(runTransaction(photoDb, async (transaction) => {
      const currentUser = await transaction.get(userRef);
      if (currentUser.data().profilePhotoUrl !== 'firestore://profile-photo') {
        transaction.update(userRef, {
          profilePhotoUrl: 'firestore://profile-photo',
        });
      }
      transaction.set(photoRef, {
        data: 'data:image/png;base64,UkVQTEFDRU1FTlQ=',
      });
    }));
    assert.equal(
      (await getDoc(photoRef)).data().data,
      'data:image/png;base64,UkVQTEFDRU1FTlQ=',
    );

    await assertFails(runTransaction(photoDb, async (transaction) => {
      const currentUser = await transaction.get(userRef);
      if (currentUser.data().profilePhotoUrl !== 'firestore://profile-photo') {
        transaction.update(userRef, {
          profilePhotoUrl: 'firestore://profile-photo',
        });
      }
      transaction.set(photoRef, {
        data: 'data:image/gif;base64,YWJj',
      });
    }));
    assert.equal(
      (await getDoc(photoRef)).data().data,
      'data:image/png;base64,UkVQTEFDRU1FTlQ=',
    );
    console.log('PASS: repeated profile photo replacement succeeds.');
    console.log('PASS: rejected profile photo replacement preserves the previous photo.');

    const legacyDb =
      testEnv.authenticatedContext('legacy-profile-student').firestore();
    await assertSucceeds(updateDoc(
      doc(legacyDb, 'users', 'legacy-profile-student'),
      { name: 'Legacy Profile Name' },
    ));
    const noSessionDb =
      testEnv.authenticatedContext(noSessionStudentId).firestore();
    await assertFails(updateDoc(
      doc(noSessionDb, 'users', noSessionStudentId),
      { name: 'No Session Name' },
    ));
    for (const deniedUid of [
      pendingProfileStudentId,
      rejectedProfileStudentId,
    ]) {
      const deniedDb = testEnv.authenticatedContext(deniedUid).firestore();
      await assertFails(updateDoc(
        doc(deniedDb, 'users', deniedUid),
        { name: 'Unapproved Name' },
      ));
    }

    const duplicateDb =
      testEnv.authenticatedContext(occupiedLrnStudentId).firestore();
    await assertFails(runTransaction(duplicateDb, async (transaction) => {
      const userRef = doc(duplicateDb, 'users', occupiedLrnStudentId);
      const oldIndex = doc(duplicateDb, 'lrnIndexes', occupiedOldLrn);
      const nextIndex = doc(duplicateDb, 'lrnIndexes', occupiedProfileLrn);
      const user = await transaction.get(userRef);
      await transaction.get(oldIndex);
      await transaction.get(nextIndex);
      transaction.update(userRef, { lrn: occupiedProfileLrn });
      transaction.set(nextIndex, {
        uid: occupiedLrnStudentId,
        createdAt: serverTimestamp(),
      });
      transaction.delete(oldIndex);
    }));
    await assertFails(updateDoc(
      doc(duplicateDb, 'users', occupiedLrnStudentId),
      { lrn: '12-not-a-number' },
    ));
    console.log('PASS: profile grade, verified email, and unique LRN Rules.');
  }
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const uid of [
      npcProgressStudentId,
      noSessionStudentId,
      sequentialNpcStudentId,
    ]) {
      await updateDoc(doc(db, 'users', uid), {
        'progress.completedNpcQuestions': [],
        'progress.completedNpcQuestionsByLevel': {},
      });
    }
  });
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const activeSession = await getDoc(
      doc(context.firestore(), 'activeSessions', noSessionStudentId),
    );
    assert.equal(activeSession.exists(), false);
  });
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await updateDoc(
      doc(context.firestore(), 'users', levelQuestionAwardStudentId),
      {
        'progress.levelQuestionAnswers.1': {
          firstOperand: 17,
          secondOperand: 23,
          operation: '+',
          correctAnswer: 40,
        },
        'progress.latestLevelQuestionAnswerLevel': '1',
      },
    );
  });
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'users', stringLevelProgressStudentId), {
      scoreBaseline: 0,
      scoreEarned: 130,
      gameScore: 130,
      progress: {
        completedLevels: ['1', '2'],
        completedNpcQuestions: questions,
        completedNpcQuestionsByLevel: {
          '1': questions,
          '2': questions,
          '3': questions,
        },
        unlockedLevels: 1,
        maxUnlockedSubLevel: { '1': 2, '2': 1, '3': 1 },
        gameModeFinalScores: { '1': 60, '2': 70 },
        latestCompletedGameModeLevel: '2',
      },
    });
  });
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'users', missingScoreFieldsStudentId), {
      scoreBaseline: deleteField(),
      scoreEarned: deleteField(),
      gameScore: deleteField(),
    });
  });
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await updateDoc(
      doc(context.firestore(), 'leaderboard', maxProgressStudentId),
      {
        displayname: maxProgressStudentId,
        name: maxProgressStudentId,
        totalscore: 3565,
      },
    );
  });
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'leaderboard', legacyLeaderboardStudentId),
      {
        uid: legacyLeaderboardStudentId,
        displayname: legacyLeaderboardStudentId,
        name: legacyLeaderboardStudentId,
        totalscore: 75,
        createdAt: timestamp,
        updatedAt: timestamp,
      },
    );
  });
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const completedLevels = Array.from({ length: 59 }, (_, index) => index + 1);
    const priorScores = Object.fromEntries(
      completedLevels.map((level) => [String(level), 60]),
    );
    await updateDoc(doc(context.firestore(), 'users', maxProgressStudentId), {
      scoreBaseline: 25,
      scoreEarned: 3540,
      gameScore: 3565,
      progress: {
        completedLevels,
        completedNpcQuestions: questions,
        completedNpcQuestionsByLevel: { '60': questions },
        unlockedLevels: 3,
        maxUnlockedSubLevel: { '1': 20, '2': 20, '3': 20 },
        gameModeFinalScores: priorScores,
        latestCompletedGameModeLevel: '59',
      },
    });
  });
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'users', pendingStudentId), {
      status: 'pending',
    });
  });
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'users', existingProgressStudentId), {
      scoreBaseline: 25,
      scoreEarned: 130,
      gameScore: 155,
      progress: {
        completedLevels: [1, 2],
        completedNpcQuestions: questions,
        completedNpcQuestionsByLevel: {
          '1': questions,
          '2': questions,
          '3': questions,
        },
        unlockedLevels: 1,
        maxUnlockedSubLevel: { '1': 2, '2': 1, '3': 1 },
        gameModeFinalScores: { '1': 60, '2': 70 },
        latestCompletedGameModeLevel: '2',
        classroomQuestHistory: {
          'previous-completion': {
            type: 'completion',
            completionTimeSeconds: 42,
            score: 30,
            correctAnswers: 3,
            totalQuestions: 3,
            completedAt: timestamp,
          },
        },
        classroomQuestCompletionTimes: { classroom_quest: 42 },
        classroomQuestResults: {},
      },
    });
  });
  await seedTeacher(teacherId);
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users', legacyProgressId), {
      ...student(legacyProgressId),
      progress: {
        ...student(legacyProgressId).progress,
        completedNpcQuestionsByLevel: {},
      },
    });
  });

  await saveGameModeAnswers(studentId);
  await recordClassroomAttempt(studentId, 'classroom-attempt-1');
  await recordClassroomAttempt(studentId, 'classroom-attempt-1');
  await completeGameMode(studentId, 60);
  await completeGameMode(studentId, 60);
  const secondStudentDb = testEnv.authenticatedContext(secondStudentId).firestore();
  await updateDoc(doc(secondStudentDb, 'users', secondStudentId), {
    'progress.levelQuestionAnswers.2': {
      firstOperand: 17,
      secondOperand: 23,
      operation: '+',
      correctAnswer: 40,
    },
    'progress.latestLevelQuestionAnswerLevel': '2',
  });
  await completeGameMode(secondStudentId, 60);
  await assertFails(completeGameMode(legacyProgressId, 60, 2));
  await completeGameMode(existingProgressStudentId, 60, 3);
  await completeGameMode(existingProgressStudentId, 60, 3);
  await completeClassroomQuest(existingProgressStudentId, 37);
  await completeClassroomQuest(existingProgressStudentId, 37);
  await completeGameMode(maxProgressStudentId, 60, 60);
  await completeGameMode(legacyLeaderboardStudentId, 60);
  await completeGameMode(legacyStringScoreStudentId, 60);
  await completeGameMode(missingScoreFieldsStudentId, 60);
  await completeGameMode(stringLevelProgressStudentId, 60, 3);
  const concurrentCompletionId =
    `classroom-completion-${newClassroomCompletionStudentId}`;
  for (let questionNumber = 1; questionNumber <= 3; questionNumber++) {
    await recordClassroomAttempt(
      newClassroomCompletionStudentId,
      `${concurrentCompletionId}-answer-${questionNumber}`,
      questionNumber,
    );
  }
  const concurrentResults = await Promise.allSettled([
    completeClassroomQuest(newClassroomCompletionStudentId, 24, {
      recordAttempts: false,
    }),
    completeClassroomQuest(newClassroomCompletionStudentId, 24, {
      recordAttempts: false,
    }),
  ]);
  assert.equal(
    concurrentResults.filter((result) => result.status === 'fulfilled').length,
    1,
  );
  assert.equal(
    concurrentResults.filter((result) => result.status === 'rejected').length,
    1,
  );
  await completeClassroomQuest(newClassroomCompletionStudentId, 24, {
    recordAttempts: false,
  });
  await assertFails(
    completeClassroomQuest(
      rejectedClassroomCompletionStudentId,
      24,
      { correctAnswers: 2, totalQuestions: 2 },
    ),
  );

  const levelQuestionAwardDb =
    testEnv.authenticatedContext(levelQuestionAwardStudentId).firestore();
  await assertFails(setDoc(
    doc(levelQuestionAwardDb, 'leaderboard', levelQuestionAwardStudentId),
    {
      uid: levelQuestionAwardStudentId,
      displayName: levelQuestionAwardStudentId,
      totalScore: 10,
      createdAt: timestamp,
      updatedAt: serverTimestamp(),
    },
  ));
  await assertSucceeds(setDoc(
    doc(levelQuestionAwardDb, 'leaderboard', levelQuestionAwardStudentId),
    {
      uid: levelQuestionAwardStudentId,
      displayName: levelQuestionAwardStudentId,
      totalScore: 0,
      createdAt: timestamp,
      updatedAt: serverTimestamp(),
    },
  ));
  await Promise.all([
    awardLevelQuestionPoints(levelQuestionAwardStudentId, 1),
    awardLevelQuestionPoints(levelQuestionAwardStudentId, 1),
  ]);
  console.log('PASS: concurrent level question awards');
  await awardLevelQuestionPoints(levelQuestionAwardStudentId, 1);
  const noAnswerDb = testEnv.authenticatedContext(attackerId).firestore();
  await assertFails(setDoc(
    doc(noAnswerDb, 'users', attackerId, 'scoreAwards', '1'),
    { points: 10, createdAt: serverTimestamp() },
  ));
  await Promise.all([
    awardMissionPoints(levelQuestionAwardStudentId, 5, 'bird-1'),
    awardMissionPoints(levelQuestionAwardStudentId, 5, 'bird-1'),
  ]);
  console.log('PASS: concurrent mission awards');
  await completeNpcQuestion(npcProgressStudentId, 1);
  console.log('PASS: concurrent NPC progress writes');
  await completeNpcQuestion(npcProgressStudentId, 1);
  for (let questionNumber = 1; questionNumber <= 6; questionNumber++) {
    await completeNpcQuestion(
      sequentialNpcStudentId,
      questionNumber,
      1,
    );
  }
  await completeNpcQuestion(sequentialNpcStudentId, 4, 1);
  for (let questionNumber = 1; questionNumber <= 6; questionNumber++) {
    await completeNpcQuestion(
      sequentialNpcStudentId,
      questionNumber,
      2,
    );
  }
  await completeNpcQuestion(sequentialNpcStudentId, 6, 2);
  const sequentialNpcDb =
    testEnv.authenticatedContext(sequentialNpcStudentId).firestore();
  await assertFails(updateDoc(doc(sequentialNpcDb, 'users', sequentialNpcStudentId), {
    'progress.completedNpcQuestions': [3],
    'progress.completedNpcQuestionsByLevel': {'1': [3]},
    'progress.latestCompletedNpcQuestionLevel': '1',
  }));
  await assertFails(updateDoc(doc(sequentialNpcDb, 'users', sequentialNpcStudentId), {
    'progress.completedNpcQuestions': [1, 2, 3, 4, 5, 6, 7],
    'progress.completedNpcQuestionsByLevel': {'1': [1, 2, 3, 4, 5, 6, 7]},
    'progress.latestCompletedNpcQuestionLevel': '1',
  }));
  const pendingStudentDb =
    testEnv.authenticatedContext(pendingStudentId).firestore();
  await assertFails(updateDoc(doc(pendingStudentDb, 'users', pendingStudentId), {
    'progress.completedNpcQuestions': [1],
    'progress.completedNpcQuestionsByLevel': {'1': [1]},
    'progress.latestCompletedNpcQuestionLevel': '1',
  }));
  await assertFails(updateDoc(doc(sequentialNpcDb, 'users', npcProgressStudentId), {
    'progress.completedNpcQuestions': [1, 2],
    'progress.completedNpcQuestionsByLevel': {'1': [1, 2]},
    'progress.latestCompletedNpcQuestionLevel': '1',
  }));
  await assertSucceeds(updateDoc(doc(sequentialNpcDb, 'users', sequentialNpcStudentId), {
    'progress.completedNpcQuestionsByLevel.2': deleteField(),
  }));
  await assertFails(updateDoc(doc(sequentialNpcDb, 'users', sequentialNpcStudentId), {
    'progress.completedNpcQuestionsByLevel.1': deleteField(),
  }));
  await assertFails(
    completeNpcQuestion(noSessionStudentId, 1),
  );
  console.log('PASS: sequential NPC questions 1-6 save for multiple levels');
  console.log('PASS: NPC save retries are idempotent and preserve progress');
  console.log('PASS: invalid question sequences and unauthorized NPC writes are rejected');
  console.log('PASS: NPC resets use the separately validated reset rule');
  console.log('PASS: Game Mode progress requires an active session');
  await assertFails(setDoc(
    doc(
      levelQuestionAwardDb,
      'users',
      levelQuestionAwardStudentId,
      'scoreAwards',
      'mission-invalid',
    ),
    { points: 15, createdAt: serverTimestamp() },
  ));
  const levelQuestionAwardEntry = (await getDoc(
    doc(levelQuestionAwardDb, 'leaderboard', levelQuestionAwardStudentId),
  )).data();
  const levelQuestionAward = (await getDoc(
    doc(levelQuestionAwardDb, 'users', levelQuestionAwardStudentId, 'scoreAwards', '1'),
  )).data();
  const npcProgressDb = testEnv.authenticatedContext(npcProgressStudentId).firestore();
  const npcProgress = (await getDoc(
    doc(npcProgressDb, 'users', npcProgressStudentId),
  )).data();
  assert.equal(levelQuestionAwardEntry.totalScore, 15);
  assert.equal(levelQuestionAward.points, 10);
  assert.deepEqual(npcProgress.progress.completedNpcQuestions, [1]);
  assert.deepEqual(npcProgress.progress.completedNpcQuestionsByLevel, {
    '1': [1],
  });

  const db = testEnv.authenticatedContext(studentId).firestore();
  const user = (await getDoc(doc(db, 'users', studentId))).data();
  const createdEntry =
    (await getDoc(doc(db, 'leaderboard', studentId))).data();
  const scoreAward = (await getDoc(
    doc(db, 'users', studentId, 'scoreAwards', 'game-mode-1'),
  )).data();
  const updatedEntry =
    (await getDoc(doc(secondStudentDb, 'leaderboard', secondStudentId))).data();
  const secondStudent =
    (await getDoc(doc(secondStudentDb, 'users', secondStudentId))).data();
  const existingProgressDb =
    testEnv.authenticatedContext(existingProgressStudentId).firestore();
  const existingProgress = (await getDoc(
    doc(existingProgressDb, 'users', existingProgressStudentId),
  )).data();
  const existingLeaderboard = (await getDoc(
    doc(existingProgressDb, 'leaderboard', existingProgressStudentId),
  )).data();
  const maxProgressDb =
    testEnv.authenticatedContext(maxProgressStudentId).firestore();
  const maxProgress = (await getDoc(
    doc(maxProgressDb, 'users', maxProgressStudentId),
  )).data();
  const maxProgressLeaderboard = (await getDoc(
    doc(maxProgressDb, 'leaderboard', maxProgressStudentId),
  )).data();
  const stringLevelDb =
    testEnv.authenticatedContext(stringLevelProgressStudentId).firestore();
  const stringLevelUser = (await getDoc(
    doc(stringLevelDb, 'users', stringLevelProgressStudentId),
  )).data();
  const legacyLeaderboardDb =
    testEnv.authenticatedContext(legacyLeaderboardStudentId).firestore();
  const legacyLeaderboard = (await getDoc(
    doc(legacyLeaderboardDb, 'leaderboard', legacyLeaderboardStudentId),
  )).data();
  const legacyStringScoreDb =
    testEnv.authenticatedContext(legacyStringScoreStudentId).firestore();
  const legacyStringScoreLeaderboard = (await getDoc(
    doc(legacyStringScoreDb, 'leaderboard', legacyStringScoreStudentId),
  )).data();
  const newClassroomDb =
    testEnv.authenticatedContext(newClassroomCompletionStudentId).firestore();
  const newClassroomUser = (await getDoc(
    doc(newClassroomDb, 'users', newClassroomCompletionStudentId),
  )).data();
  const rejectedClassroomDb =
    testEnv.authenticatedContext(rejectedClassroomCompletionStudentId).firestore();
  const rejectedClassroomUser = (await getDoc(
    doc(rejectedClassroomDb, 'users', rejectedClassroomCompletionStudentId),
  )).data();
  const missingScoreDb =
    testEnv.authenticatedContext(missingScoreFieldsStudentId).firestore();
  const missingScoreUser = (await getDoc(
    doc(missingScoreDb, 'users', missingScoreFieldsStudentId),
  )).data();
  const missingScoreLeaderboard = (await getDoc(
    doc(missingScoreDb, 'leaderboard', missingScoreFieldsStudentId),
  )).data();
  assert.equal(user.progress.gameModeFinalScores['1'], 60);
  assert.equal(user.progress.completedLevels.includes(1), true);
  assert.equal(user.scoreEarned, 60);
  assert.equal(user.gameScore, 60);
  assert.equal(user.progress.questAttempts, 1);
  assert.equal(createdEntry.totalScore, 60);
  assert.equal(scoreAward.points, 60);
  assert.equal(updatedEntry.totalScore, 95);
  assert.equal(secondStudent.progress.levelQuestionAnswers['2'].correctAnswer, 40);
  assert.deepEqual(existingProgress.progress.completedLevels, [1, 2, 3]);
  assert.deepEqual(existingProgress.progress.gameModeFinalScores, {
    '1': 60,
    '2': 70,
    '3': 60,
  });
  assert.equal(existingProgress.scoreEarned, 190);
  assert.equal(existingProgress.gameScore, 215);
  assert.equal(existingLeaderboard.totalScore, 215);
  assert.equal(existingProgress.progress.classroomQuestHistory['previous-completion'].score, 30);
  assert.equal(existingProgress.progress.classroomQuestHistory['classroom-completion-existing-progress-student'].score, 30);
  assert.equal(existingProgress.progress.classroomQuestResults.classroom_quest.status, 'completed');
  assert.equal(existingProgress.progress.classroomQuestResults.classroom_quest.correctAnswers, 3);
  assert.equal(existingProgress.progress.classroomQuestResults.classroom_quest.totalQuestions, 3);
  assert.equal(existingProgress.progress.classroomQuestResults.classroom_quest.score, 30);
  assert.equal(
    existingProgress.progress.classroomQuestResults.classroom_quest.completedAt
      instanceof Timestamp,
    true,
  );
  assert.equal(
    existingProgress.progress.classroomQuestHistory[
      'classroom-completion-existing-progress-student'
    ].completedAt instanceof Timestamp,
    true,
  );
  assert.equal(existingProgress.progress.classroomQuestCompletionTimes.classroom_quest, 37);
  assert.equal(maxProgress.progress.completedLevels.length, 60);
  assert.equal(maxProgress.progress.gameModeFinalScores['60'], 60);
  assert.equal(maxProgress.scoreEarned, 3600);
  assert.equal(maxProgress.gameScore, 3625);
  assert.equal(maxProgressLeaderboard.totalScore, 3625);
  assert.deepEqual(stringLevelUser.progress.completedLevels, ['1', '2', 3]);
  assert.equal(stringLevelUser.progress.gameModeFinalScores['3'], 60);
  assert.equal(Object.hasOwn(maxProgressLeaderboard, 'totalscore'), false);
  assert.equal(Object.hasOwn(maxProgressLeaderboard, 'displayname'), false);
  assert.equal(Object.hasOwn(maxProgressLeaderboard, 'name'), false);
  assert.equal(legacyLeaderboard.totalScore, 135);
  assert.equal(Object.hasOwn(legacyLeaderboard, 'totalscore'), false);
  assert.equal(Object.hasOwn(legacyLeaderboard, 'displayname'), false);
  assert.equal(Object.hasOwn(legacyLeaderboard, 'name'), false);
  assert.equal(legacyStringScoreLeaderboard.totalScore, 135);
  assert.equal(Object.hasOwn(legacyStringScoreLeaderboard, 'totalscore'), false);
  assert.equal(
    newClassroomUser.progress.classroomQuestResults.classroom_quest.score,
    30,
  );
  assert.equal(
    Object.hasOwn(
      rejectedClassroomUser.progress.classroomQuestResults ?? {},
      'classroom_quest',
    ),
    false,
  );
  assert.equal(
    (await getDoc(doc(
      newClassroomDb,
      'users',
      newClassroomCompletionStudentId,
      'classroomQuestDailyCompletions',
      classroomQuestDayKey(),
    ))).exists(),
    true,
  );
  assert.equal(
    (await getDocs(collection(
      newClassroomDb,
      'users',
      newClassroomCompletionStudentId,
      'classroomQuestDailyCompletions',
    ))).size,
    1,
  );
  await assertFails(recordClassroomAttempt(
    newClassroomCompletionStudentId,
    'attempt-after-daily-completion',
  ));
  await assertFails(setDoc(doc(
    newClassroomDb,
    'users',
    newClassroomCompletionStudentId,
    'classroomQuestDailyCompletions',
    '2099-01-01',
  ), {
    uid: newClassroomCompletionStudentId,
    questId: 'classroom_quest',
    dayKey: '2099-01-01',
    completionId: 'forged-completion',
    questionIds: ['worksheet-1', 'worksheet-2', 'worksheet-3'],
    correctAttemptIds: ['a', 'b', 'c'],
    completionTimeSeconds: 24,
    correctAnswers: 3,
    totalQuestions: 3,
    score: 30,
    completedAt: serverTimestamp(),
  }));
  assert.equal(
    (await getDocs(collection(
      rejectedClassroomDb,
      'users',
      rejectedClassroomCompletionStudentId,
      'classroomQuestDailyCompletions',
    ))).size,
    0,
  );
  assert.equal(
    Object.keys(newClassroomUser.progress.classroomQuestHistory).length,
    1,
  );
  assert.equal(missingScoreUser.scoreEarned, 60);
  assert.equal(missingScoreUser.gameScore, 60);
  assert.equal(missingScoreLeaderboard.totalScore, 60);
  assert.equal((await getDoc(
    doc(db, 'users', studentId, 'gameModeAttempts', 'level-1-6'),
  )).exists(), true);

  const ownGameModeHistory = query(
    collection(db, 'users', studentId, 'gameModeAttempts'),
    orderBy('attemptedAt', 'desc'),
  );
  const ownClassroomHistory = query(
    collection(db, 'users', studentId, 'classroomQuestAttempts'),
    orderBy('attemptedAt', 'desc'),
  );
  assert.equal((await assertSucceeds(getDocs(ownGameModeHistory))).size, 6);
  assert.equal((await assertSucceeds(getDocs(ownClassroomHistory))).size, 1);

  const teacherDb = testEnv.authenticatedContext(teacherId).firestore();
  assert.equal((await assertSucceeds(getDocs(query(
    collection(teacherDb, 'users', studentId, 'gameModeAttempts'),
    orderBy('attemptedAt', 'desc'),
  )))).size, 6);
  assert.equal((await assertSucceeds(getDocs(query(
    collection(teacherDb, 'users', studentId, 'classroomQuestAttempts'),
    orderBy('attemptedAt', 'desc'),
  )))).size, 1);
  await assertFails(getDocs(query(
    collection(db, 'users', secondStudentId, 'gameModeAttempts'),
    orderBy('attemptedAt', 'desc'),
  )));
  await assertFails(getDocs(query(
    collection(teacherDb, 'users', pendingStudentId, 'classroomQuestAttempts'),
    orderBy('attemptedAt', 'desc'),
  )));

  const attackerDb = testEnv.authenticatedContext(attackerId).firestore();
  await updateDoc(doc(attackerDb, 'leaderboard', attackerId), {
    totalScore: 10,
    updatedAt: serverTimestamp(),
  });
  assert.equal((await getDoc(
    doc(attackerDb, 'leaderboard', attackerId),
  )).data().totalScore, 10);
  await assertFails(updateDoc(doc(attackerDb, 'leaderboard', attackerId), {
    totalScore: 70,
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(attackerDb, 'leaderboard', studentId), {
    totalScore: 1060,
    updatedAt: serverTimestamp(),
  }));
  await assertFails(setDoc(
    doc(db, 'users', studentId, 'scoreAwards', 'game-mode-2'),
    { points: 60, createdAt: serverTimestamp() },
  ));

  console.log('PASS: Game Mode creates and updates leaderboard with 60 points.');
  console.log('PASS: retry does not duplicate user or leaderboard points.');
  console.log('PASS: Level Question score awards are limited to one award per level.');
  console.log('PASS: Level Question score awards require a saved correct answer.');
  console.log('PASS: mission score award retries are idempotent and limited to 5 or 10 points.');
  console.log('PASS: concurrent NPC progress saves commit one completion.');
  console.log('PASS: a new leaderboard entry must start at zero before awarding points.');
  console.log('PASS: existing scores, completed levels, and progress are preserved.');
  console.log('PASS: Game Mode completion works with 59 existing scores and levels.');
  console.log('PASS: missing legacy score fields initialize without overwriting progress.');
  console.log('PASS: numeric-string legacy leaderboard scores remain awardable.');
  console.log('PASS: Classroom Quest completion saves once and preserves prior history.');
  console.log('PASS: new-student Classroom Quest completion is idempotent.');
  console.log('PASS: daily completion is one-per-Manila-day and atomic across concurrent clients.');
  console.log('PASS: invalid Classroom Quest completion counts are rejected.');
  console.log('PASS: Stage Answer progress remains writable.');
  console.log('PASS: all six Game Mode answer documents remain writable.');
  console.log('PASS: Classroom Quest attempt and count save once on retry.');
  console.log('PASS: student and approved-teacher history reads are scoped correctly.');
  console.log('PASS: standalone score jumps, other owners, and unpaired awards are rejected.');
} finally {
  await testEnv.cleanup();
}