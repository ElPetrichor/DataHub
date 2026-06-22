<?php

declare(strict_types=1);

namespace App\Tests\Controller\Admin;

use App\Domain\Activity\ActivityId;
use App\Domain\Activity\ActivityOverride\ActivityOverride;
use App\Domain\Activity\ActivityOverride\ActivityOverrideRepository;
use App\Domain\Activity\ActivityRepository;
use App\Domain\Activity\ActivityWithRawData;
use App\Infrastructure\ValueObject\Time\SerializableDateTime;
use App\Tests\Domain\Activity\ActivityBuilder;

class ActivitiesRequestHandlerTest extends AdminWebTestCase
{
    public function testAnonymousUsersAreRedirectedToTheLoginPage(): void
    {
        $this->client->request('GET', '/admin/activities');

        $this->assertResponseRedirects('/admin/login');
    }

    public function testRendersTheTableWithActivities(): void
    {
        $activityRepository = static::getContainer()->get(ActivityRepository::class);
        $activity = ActivityBuilder::fromDefaults()
            ->withActivityId(ActivityId::fromUnprefixed(1))
            ->withName('Morning Ride')
            ->build();
        $activityRepository->add(ActivityWithRawData::fromState($activity, ['raw' => 'data']));

        $this->client->loginUser($this->adminUser());

        $crawler = $this->client->request('GET', '/admin/activities');

        $this->assertResponseIsSuccessful();
        $this->assertCount(1, $crawler->filter('table.data-table tbody tr'));
        $this->assertStringContainsString('Morning Ride', $crawler->filter('table.data-table')->text());
        $this->assertCount(0, $crawler->filter('[data-activity-revert]'));
    }

    public function testShowsEditedBadgeAndRevertButtonForOverriddenActivities(): void
    {
        $activityRepository = static::getContainer()->get(ActivityRepository::class);
        $activity = ActivityBuilder::fromDefaults()
            ->withActivityId(ActivityId::fromUnprefixed(1))
            ->build();
        $activityRepository->add(ActivityWithRawData::fromState($activity, ['raw' => 'data']));

        static::getContainer()->get(ActivityOverrideRepository::class)->save(ActivityOverride::fromState(
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

        $this->client->loginUser($this->adminUser());

        $crawler = $this->client->request('GET', '/admin/activities');

        $this->assertResponseIsSuccessful();
        $this->assertStringContainsString('edited', $crawler->filter('table.data-table')->text());
        $this->assertCount(1, $crawler->filter('[data-activity-revert]'));
    }

    public function testRendersTheEmptyStateWhenThereAreNoActivities(): void
    {
        $this->client->loginUser($this->adminUser());

        $crawler = $this->client->request('GET', '/admin/activities');

        $this->assertResponseIsSuccessful();
        $this->assertStringContainsString('No activities found.', $crawler->filter('body')->text());
    }
}
