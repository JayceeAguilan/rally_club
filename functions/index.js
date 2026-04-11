const logger = require("firebase-functions/logger");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

initializeApp();

const db = getFirestore();
const DUPR_BASELINE = 2.0;
const DUPR_MINIMUM = 2.0;
const DUPR_MAXIMUM = 8.0;
const DUPR_SCALE = 0.75;
const PLAYER_BATCH_LIMIT = 400;
const GUEST_ID_PREFIX = "guest:";

function splitCsvValues(value) {
  return String(value || "")
      .split(",")
      .map((entry) => entry.trim())
      .filter((entry) => entry.length > 0);
}

function parseRatingSnapshots(value) {
  return splitCsvValues(value).map((entry) =>
    normalizeRating(Number.parseFloat(entry))
  );
}

function normalizeRating(value) {
  const rawValue = Number.isFinite(value) ? value : DUPR_BASELINE;
  const clamped = Math.min(DUPR_MAXIMUM, Math.max(DUPR_MINIMUM, rawValue));
  return Math.round(clamped * 100) / 100;
}

function expectedScore({playerRating, opponentRating}) {
  const exponent = (normalizeRating(opponentRating) -
    normalizeRating(playerRating)) / DUPR_SCALE;
  return 1 / (1 + (10 ** exponent));
}

function kFactorForMatches(ratedMatches) {
  if (ratedMatches < 5) {
    return 0.18;
  }
  if (ratedMatches < 15) {
    return 0.14;
  }
  return 0.1;
}

function ratingDelta({playerRating, opponentRating, didWin, ratedMatches}) {
  const actual = didWin ? 1 : 0;
  const expected = expectedScore({playerRating, opponentRating});
  const rawDelta = kFactorForMatches(ratedMatches) * (actual - expected);
  return Math.round(rawDelta * 100) / 100;
}

function isGuestPlayerId(playerId) {
  return String(playerId || "").trim().startsWith(GUEST_ID_PREFIX);
}

function buildTeamContext({ids, snapshotRatings, currentRatings}) {
  const context = new Map();

  ids.forEach((playerId, index) => {
    const normalizedId = String(playerId || "").trim();
    if (!normalizedId) {
      return;
    }

    const currentRating = currentRatings.get(normalizedId);
    const snapshotRating = index < snapshotRatings.length ?
      snapshotRatings[index] :
      DUPR_BASELINE;
    context.set(normalizedId, currentRating ?? snapshotRating);
  });

  return context;
}

function average(values) {
  const list = Array.from(values);
  if (list.length === 0) {
    return DUPR_BASELINE;
  }

  const sum = list.reduce((total, value) => total + value, 0);
  return normalizeRating(sum / list.length);
}

function replayDuprRatings({players, matches}) {
  const trackedPlayerIds = players
      .filter((player) => player.id && !player.isGuest)
      .map((player) => player.id);

  const ratings = new Map(
      trackedPlayerIds.map((playerId) => [playerId, DUPR_BASELINE]),
  );
  const ratedMatches = new Map(
      trackedPlayerIds.map((playerId) => [playerId, 0]),
  );
  const lastResults = new Map(
      trackedPlayerIds.map((playerId) => [playerId, "none"]),
  );

  const sortedMatches = [...matches].sort((left, right) =>
    String(left.date || "").localeCompare(String(right.date || ""))
  );

  for (const match of sortedMatches) {
    const teamAIds = splitCsvValues(match.teamAPlayerIds);
    const teamBIds = splitCsvValues(match.teamBPlayerIds);
    const teamAContext = buildTeamContext({
      ids: teamAIds,
      snapshotRatings: parseRatingSnapshots(match.teamAPlayerRatings),
      currentRatings: ratings,
    });
    const teamBContext = buildTeamContext({
      ids: teamBIds,
      snapshotRatings: parseRatingSnapshots(match.teamBPlayerRatings),
      currentRatings: ratings,
    });

    if (teamAContext.size === 0 || teamBContext.size === 0) {
      continue;
    }

    const teamAAverage = average(teamAContext.values());
    const teamBAverage = average(teamBContext.values());

    applyMatchResult({
      participantIds: teamAIds,
      didWin: match.winningSide === "A",
      opponentAverage: teamBAverage,
      ratings,
      ratedMatches,
      lastResults,
    });
    applyMatchResult({
      participantIds: teamBIds,
      didWin: match.winningSide === "B",
      opponentAverage: teamAAverage,
      ratings,
      ratedMatches,
      lastResults,
    });
  }

  const generatedAt = new Date().toISOString();
  const lastUpdatedAt = sortedMatches.length > 0 ?
    String(sortedMatches[sortedMatches.length - 1].date || generatedAt) :
    generatedAt;
  const replayedRatings = {};

  trackedPlayerIds.forEach((playerId) => {
    replayedRatings[playerId] = {
      rating: ratings.get(playerId) ?? DUPR_BASELINE,
      ratedMatches: ratedMatches.get(playerId) ?? 0,
      updatedAt: lastUpdatedAt,
      lastResult: lastResults.get(playerId) ?? "none",
    };
  });

  return replayedRatings;
}

function applyMatchResult({
  participantIds,
  didWin,
  opponentAverage,
  ratings,
  ratedMatches,
  lastResults,
}) {
  participantIds.forEach((playerId) => {
    const normalizedId = String(playerId || "").trim();
    if (!normalizedId || !ratings.has(normalizedId)) {
      return;
    }

    const currentRating = ratings.get(normalizedId) ?? DUPR_BASELINE;
    const currentRatedMatches = ratedMatches.get(normalizedId) ?? 0;
    const delta = ratingDelta({
      playerRating: currentRating,
      opponentRating: opponentAverage,
      didWin,
      ratedMatches: currentRatedMatches,
    });

    ratings.set(normalizedId, normalizeRating(currentRating + delta));
    ratedMatches.set(normalizedId, currentRatedMatches + 1);
    lastResults.set(normalizedId, didWin ? "win" : "loss");
  });
}

async function recalculateClubDuprRatings({clubId, reason, migrationRef}) {
  if (!clubId) {
    logger.warn("DUPR recalculation skipped because clubId was missing.", {
      reason,
    });
    return;
  }

  const [playersSnapshot, matchesSnapshot] = await Promise.all([
    db.collection("players")
        .where("clubId", "==", clubId)
        .where("isActive", "==", 1)
        .get(),
    db.collection("matches")
        .where("clubId", "==", clubId)
        .get(),
  ]);

  const players = playersSnapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      isGuest: data.isGuest === 1 || data.isGuest === true ||
        isGuestPlayerId(doc.id),
    };
  });
  const matches = matchesSnapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      teamAPlayerIds: data.teamAPlayerIds || "",
      teamBPlayerIds: data.teamBPlayerIds || "",
      teamAPlayerRatings: data.teamAPlayerRatings || "",
      teamBPlayerRatings: data.teamBPlayerRatings || "",
      winningSide: data.winningSide || "",
      date: data.date || "",
    };
  });

  const replayedRatings = replayDuprRatings({players, matches});
  const playerIds = Object.keys(replayedRatings);
  const updateTimestamp = new Date().toISOString();

  if (playerIds.length === 0) {
    if (migrationRef) {
      await migrationRef.set({
        status: "completed",
        processedAt: updateTimestamp,
        playersUpdated: 0,
      }, {merge: true});
    }
    logger.info("DUPR recalculation completed with no tracked players.", {
      clubId,
      reason,
      matchesProcessed: matches.length,
    });
    return;
  }

  const commits = [];
  let batch = db.batch();
  let operations = 0;

  for (const playerDoc of playersSnapshot.docs) {
    const snapshot = replayedRatings[playerDoc.id];
    if (!snapshot) {
      continue;
    }

    batch.update(playerDoc.ref, {
      duprRating: snapshot.rating,
      duprMatchesPlayed: snapshot.ratedMatches,
      duprLastUpdatedAt: snapshot.updatedAt,
      lastResult: snapshot.lastResult,
      updatedAt: updateTimestamp,
    });
    operations += 1;

    if (operations >= PLAYER_BATCH_LIMIT) {
      commits.push(batch.commit());
      batch = db.batch();
      operations = 0;
    }
  }

  if (operations > 0) {
    commits.push(batch.commit());
  }

  await Promise.all(commits);

  if (migrationRef) {
    await migrationRef.set({
      status: "completed",
      processedAt: updateTimestamp,
      playersUpdated: playerIds.length,
      matchesProcessed: matches.length,
    }, {merge: true});
  }

  logger.info("DUPR ratings recalculated.", {
    clubId,
    reason,
    playersUpdated: playerIds.length,
    matchesProcessed: matches.length,
  });
}

exports.recalculateDuprRatingsOnMatchCreate = onDocumentCreated(
    {
      document: "matches/{matchId}",
      region: "us-central1",
      retry: false,
    },
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) {
        logger.warn("Match DUPR trigger fired without snapshot data.");
        return;
      }

      const match = snapshot.data();

      await recalculateClubDuprRatings({
        clubId: match.clubId,
        reason: "match-create",
      });
    },
);

exports.backfillDuprRatings = onDocumentCreated(
    {
      document: "_migrations/{docId}",
      region: "us-central1",
      retry: false,
    },
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) {
        logger.warn("DUPR backfill trigger fired without snapshot data.");
        return;
      }

      const migration = snapshot.data();
      if (migration.type !== "dupr-backfill") {
        return;
      }

      const startedAt = new Date().toISOString();
      await snapshot.ref.set({
        status: "running",
        startedAt,
      }, {merge: true});

      try {
        await recalculateClubDuprRatings({
          clubId: migration.clubId,
          reason: "migration-backfill",
          migrationRef: snapshot.ref,
        });
      } catch (error) {
        await snapshot.ref.set({
          status: "failed",
          failedAt: new Date().toISOString(),
          error: String(error),
        }, {merge: true});
        logger.error("DUPR backfill failed.", {
          docId: snapshot.id,
          clubId: migration.clubId,
          error: String(error),
        });
        throw error;
      }
    },
);