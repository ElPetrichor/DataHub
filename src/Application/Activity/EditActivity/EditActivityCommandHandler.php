<?php

declare(strict_types=1);

namespace App\Application\Activity\EditActivity;

use App\Domain\Activity\ActivityOverride\ActivityOverride;
use App\Domain\Activity\ActivityOverride\ActivityOverrideRepository;
use App\Domain\Activity\ActivityRepository;
use App\Infrastructure\CQRS\Command\Command;
use App\Infrastructure\CQRS\Command\CommandHandler;
use App\Infrastructure\ValueObject\Time\SerializableDateTime;

final readonly class EditActivityCommandHandler implements CommandHandler
{
    public function __construct(
        private ActivityRepository $activityRepository,
        private ActivityOverrideRepository $activityOverrideRepository,
    ) {
    }

    public function handle(Command $command): void
    {
        assert($command instanceof EditActivity);

        // Throws EntityNotFound when the activity does not exist.
        $this->activityRepository->find($command->getActivityId());

        $this->activityOverrideRepository->save(ActivityOverride::fromState(
            activityId: $command->getActivityId(),
            name: $command->getName(),
            description: $command->getDescription(),
            sportType: $command->getSportType(),
            distanceInMeter: $command->getDistanceInMeter(),
            elevationInMeter: $command->getElevationInMeter(),
            gearId: $command->getGearId(),
            isCommute: $command->isCommute(),
            updatedAt: SerializableDateTime::fromString('now'),
        ));
    }
}
