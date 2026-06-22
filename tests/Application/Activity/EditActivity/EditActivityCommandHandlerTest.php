<?php

declare(strict_types=1);

namespace App\Tests\Application\Activity\EditActivity;

use App\Application\Activity\EditActivity\EditActivity;
use App\Domain\Activity\ActivityId;
use App\Domain\Activity\ActivityOverride\ActivityOverrideRepository;
use App\Domain\Activity\ActivityRepository;
use App\Domain\Activity\ActivityWithRawData;
use App\Domain\Activity\SportType\SportType;
use App\Domain\Gear\GearId;
use App\Infrastructure\CQRS\Command\Bus\CommandBus;
use App\Infrastructure\Exception\EntityNotFound;
use App\Tests\ContainerTestCase;
use App\Tests\Domain\Activity\ActivityBuilder;

class EditActivityCommandHandlerTest extends ContainerTestCase
{
    private CommandBus $commandBus;
    private ActivityRepository $activityRepository;
    private ActivityOverrideRepository $activityOverrideRepository;

    public function testHandle(): void
    {
        $activity = ActivityBuilder::fromDefaults()
            ->withActivityId(ActivityId::fromUnprefixed(1))
            ->withSportType(SportType::RIDE)
            ->build();
        $this->activityRepository->add(ActivityWithRawData::fromState($activity, ['raw' => 'data']));

        $this->commandBus->dispatch(EditActivity::fromPayload([
            'activityId' => (string) $activity->getId(),
            'name' => 'Corrected name',
            'description' => 'Corrected description',
            'sportType' => SportType::TRAIL_RUN->value,
            'distance' => 12.345,
            'elevation' => 250,
            'gearId' => null,
            'isCommute' => true,
        ]));

        $persisted = $this->activityRepository->find($activity->getId());
        $this->assertSame('Corrected name', $persisted->getOriginalName());
        $this->assertSame('Corrected description', $persisted->getDescription());
        $this->assertEquals(SportType::TRAIL_RUN, $persisted->getSportType());
        $this->assertTrue($persisted->isCommute());

        $override = $this->activityOverrideRepository->find($activity->getId());
        $this->assertNotNull($override);
        $this->assertSame('Corrected name', $override->getName());
    }

    public function testHandleWithGearOverride(): void
    {
        $activity = ActivityBuilder::fromDefaults()
            ->withActivityId(ActivityId::fromUnprefixed(1))
            ->build();
        $this->activityRepository->add(ActivityWithRawData::fromState($activity, ['raw' => 'data']));

        $this->commandBus->dispatch(EditActivity::fromPayload([
            'activityId' => (string) $activity->getId(),
            'name' => 'Name',
            'description' => '',
            'sportType' => SportType::RIDE->value,
            'distance' => 10,
            'elevation' => 0,
            'gearId' => (string) GearId::fromUnprefixed('my-bike'),
            'isCommute' => false,
        ]));

        $persisted = $this->activityRepository->find($activity->getId());
        $this->assertEquals(GearId::fromUnprefixed('my-bike'), $persisted->getGearId());
    }

    public function testHandleThrowsWhenActivityDoesNotExist(): void
    {
        $this->expectExceptionObject(new EntityNotFound('Activity "activity-1" not found'));

        $this->commandBus->dispatch(EditActivity::fromPayload([
            'activityId' => 'activity-1',
            'name' => 'Name',
            'description' => '',
            'sportType' => SportType::RIDE->value,
            'distance' => 10,
            'elevation' => 0,
            'gearId' => null,
            'isCommute' => false,
        ]));
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
