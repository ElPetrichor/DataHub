<?php

declare(strict_types=1);

namespace App\Tests\Application\Activity\RevertActivityOverride;

use App\Application\Activity\RevertActivityOverride\RevertActivityOverride;
use App\Domain\Activity\ActivityId;
use App\Domain\Activity\ActivityOverride\ActivityOverride;
use App\Domain\Activity\ActivityOverride\ActivityOverrideRepository;
use App\Domain\Activity\ActivityRepository;
use App\Domain\Activity\ActivityWithRawData;
use App\Infrastructure\CQRS\Command\Bus\CommandBus;
use App\Infrastructure\ValueObject\Time\SerializableDateTime;
use App\Tests\ContainerTestCase;
use App\Tests\Domain\Activity\ActivityBuilder;

class RevertActivityOverrideCommandHandlerTest extends ContainerTestCase
{
    private CommandBus $commandBus;
    private ActivityRepository $activityRepository;
    private ActivityOverrideRepository $activityOverrideRepository;

    public function testHandleDeletesTheOverride(): void
    {
        $activity = ActivityBuilder::fromDefaults()
            ->withActivityId(ActivityId::fromUnprefixed(1))
            ->build();
        $this->activityRepository->add(ActivityWithRawData::fromState($activity, ['raw' => 'data']));

        $this->activityOverrideRepository->save(ActivityOverride::fromState(
            activityId: $activity->getId(),
            name: 'Corrected name',
            description: null,
            sportType: null,
            distanceInMeter: null,
            elevationInMeter: null,
            gearId: null,
            isCommute: null,
            updatedAt: SerializableDateTime::fromString('now'),
        ));

        $this->commandBus->dispatch(RevertActivityOverride::fromPayload([
            'activityId' => (string) $activity->getId(),
        ]));

        $this->assertNull($this->activityOverrideRepository->find($activity->getId()));
        $this->assertSame($activity->getOriginalName(), $this->activityRepository->find($activity->getId())->getOriginalName());
    }

    #[\Override]
    protected function setUp(): void
    {
        parent::setUp();

        $this->commandBus = $this->getContainer()->get(CommandBus::class);
        $this->activityRepository = $this->getContainer()->get(ActivityRepository::class);
        $this->activityOverrideRepository = $this->getContainer()->get(ActivityOverrideRepository::class);
    }
}
