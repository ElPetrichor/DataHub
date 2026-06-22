<?php

declare(strict_types=1);

namespace App\Domain\Activity\ActivityOverride;

use App\Domain\Activity\ActivityId;

interface ActivityOverrideRepository
{
    public function find(ActivityId $activityId): ?ActivityOverride;

    /**
     * @return array<string, ActivityOverride> keyed by the unprefixed activityId string
     */
    public function findAll(): array;

    public function save(ActivityOverride $activityOverride): void;

    public function delete(ActivityId $activityId): void;
}