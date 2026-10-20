-- Store-and-forward chat: messages are queued per recipient and deleted once delivered.
ALTER TABLE "Message" ADD COLUMN "recipientId" TEXT;
ALTER TABLE "Message" ADD COLUMN "expiresAt" TIMESTAMP(3);

-- Existing history is treated as undelivered for the other member (devices pull it once, then it is deleted).
UPDATE "Message" m SET "recipientId" = cm."userId"
FROM "ConversationMember" cm
WHERE cm."conversationId" = m."conversationId" AND cm."userId" <> m."senderId";
DELETE FROM "Message" WHERE "recipientId" IS NULL;
UPDATE "Message" SET "expiresAt" = NOW() + INTERVAL '30 days';

ALTER TABLE "Message" ALTER COLUMN "recipientId" SET NOT NULL;
ALTER TABLE "Message" ALTER COLUMN "expiresAt" SET NOT NULL;

CREATE INDEX "Message_recipientId_createdAt_idx" ON "Message"("recipientId", "createdAt");
CREATE INDEX "Message_expiresAt_idx" ON "Message"("expiresAt");
