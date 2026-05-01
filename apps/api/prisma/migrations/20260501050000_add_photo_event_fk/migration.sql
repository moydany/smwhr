-- AlterTable
ALTER TABLE "photos" ADD COLUMN "eventId" UUID;

-- CreateIndex
CREATE INDEX "photos_userId_eventId_idx" ON "photos"("userId", "eventId");

-- AddForeignKey
ALTER TABLE "photos" ADD CONSTRAINT "photos_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;
