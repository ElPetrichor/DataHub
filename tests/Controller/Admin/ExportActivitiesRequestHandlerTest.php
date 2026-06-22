<?php

declare(strict_types=1);

namespace App\Tests\Controller\Admin;

use App\Domain\Activity\ActivityId;
use App\Domain\Activity\ActivityRepository;
use App\Domain\Activity\ActivityWithRawData;
use App\Tests\Domain\Activity\ActivityBuilder;
use PhpOffice\PhpSpreadsheet\IOFactory;

class ExportActivitiesRequestHandlerTest extends AdminWebTestCase
{
    public function testAnonymousUsersAreRedirectedToTheLoginPage(): void
    {
        $this->client->request('GET', '/admin/activities/export');

        $this->assertResponseRedirects('/admin/login');
    }

    public function testExportsActivitiesAsExcel(): void
    {
        $activityRepository = static::getContainer()->get(ActivityRepository::class);
        $activity = ActivityBuilder::fromDefaults()
            ->withActivityId(ActivityId::fromUnprefixed(1))
            ->withName('Morning Ride')
            ->build();
        $activityRepository->add(ActivityWithRawData::fromState($activity, ['raw' => 'data']));

        $this->client->loginUser($this->adminUser());
        $this->client->request('GET', '/admin/activities/export');

        $response = $this->client->getResponse();
        $this->assertResponseIsSuccessful();
        $this->assertSame(
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            $response->headers->get('Content-Type')
        );
        $this->assertStringContainsString('attachment; filename="activities-export-', (string) $response->headers->get('Content-Disposition'));

        $tmpFile = tempnam(sys_get_temp_dir(), 'xlsx');
        file_put_contents($tmpFile, $response->getContent());
        $spreadsheet = IOFactory::load($tmpFile);
        unlink($tmpFile);

        $sheet = $spreadsheet->getActiveSheet();
        $this->assertSame('Date', $sheet->getCell('A1')->getValue());
        $this->assertSame('Name', $sheet->getCell('B1')->getValue());
        $this->assertSame('Morning Ride', $sheet->getCell('B2')->getValue());
    }
}
