<?php

declare(strict_types=1);

namespace App\Controller\Admin;

use App\Domain\Activity\ActivityOverride\ActivityOverrideRepository;
use App\Domain\Activity\EnrichedActivities;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use Symfony\Component\HttpFoundation\StreamedResponse;
use Symfony\Component\HttpKernel\Attribute\AsController;
use Symfony\Component\Routing\Attribute\Route;

#[AsController]
final readonly class ExportActivitiesRequestHandler
{
    /**
     * @var string[]
     */
    private const array HEADERS = [
        'Date', 'Name', 'Sport type', 'Distance (km)', 'Elevation (m)',
        'Moving time (s)', 'Gear', 'Commute', 'Description', 'Edited',
    ];

    public function __construct(
        private EnrichedActivities $enrichedActivities,
        private ActivityOverrideRepository $activityOverrideRepository,
    ) {
    }

    #[Route(path: '/admin/activities/export', name: 'admin_activities_export', methods: ['GET'], priority: 10)]
    public function handle(): StreamedResponse
    {
        $overriddenActivityIds = array_keys($this->activityOverrideRepository->findAll());

        $spreadsheet = new Spreadsheet();
        $sheet = $spreadsheet->getActiveSheet();
        $sheet->setTitle('Activities');
        $sheet->fromArray(self::HEADERS, null, 'A1');

        $row = 2;
        foreach ($this->enrichedActivities->findAll() as $activity) {
            $sheet->fromArray([
                $activity->getStartDate()->format('Y-m-d H:i'),
                $activity->getName(),
                $activity->getSportType()->value,
                round($activity->getDistance()->toFloat(), 2),
                round($activity->getElevation()->toFloat()),
                $activity->getMovingTimeInSeconds(),
                $activity->getGearName() ?? '',
                $activity->isCommute() ? 'Yes' : 'No',
                $activity->getDescription(),
                in_array((string) $activity->getId(), $overriddenActivityIds, true) ? 'Yes' : 'No',
            ], null, sprintf('A%d', $row));
            ++$row;
        }

        $writer = new Xlsx($spreadsheet);
        $filename = sprintf('activities-export-%s.xlsx', date('Y-m-d'));

        return new StreamedResponse(
            function () use ($writer): void {
                $writer->save('php://output');
            },
            200,
            [
                'Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                'Content-Disposition' => sprintf('attachment; filename="%s"', $filename),
            ]
        );
    }
}
