-- CreateTable
CREATE TABLE "verification_tasks" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "eventId" UUID NOT NULL,
    "taskId" VARCHAR(40) NOT NULL,
    "status" VARCHAR(20) NOT NULL,
    "evidenceAt" TIMESTAMP(3),
    "evidenceRefId" UUID,
    "progressN" INTEGER,
    "progressM" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "verification_tasks_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "verification_tasks_userId_eventId_idx" ON "verification_tasks"("userId", "eventId");

-- CreateIndex
CREATE INDEX "verification_tasks_eventId_taskId_idx" ON "verification_tasks"("eventId", "taskId");

-- CreateIndex
CREATE UNIQUE INDEX "verification_tasks_userId_eventId_taskId_key" ON "verification_tasks"("userId", "eventId", "taskId");

-- AddForeignKey
ALTER TABLE "verification_tasks" ADD CONSTRAINT "verification_tasks_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "verification_tasks" ADD CONSTRAINT "verification_tasks_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;
