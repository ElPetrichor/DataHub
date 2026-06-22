<?php

declare(strict_types=1);

namespace App\Controller\Admin;

use App\Domain\Activity\ActivityOverride\ActivityOverrideRepository;
use App\Domain\Activity\EnrichedActivities;
use App\Domain\Activity\SportType\SportType;
use App\Domain\Gear\GearRepository;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Attribute\AsController;
use Symfony\Component\Routing\Attribute\Route;
use Twig\Environment;

#[AsController]
final readonly class ActivitiesRequestHandler
{
    public function __construct(
        private Environment $twig,
        private EnrichedActivities $enrichedActivities,
        private ActivityOverrideRepository $activityOverrideRepository,
        private GearRepository $gearRepository,
    ) {
    }

    #[Route(path: '/admin/activities', name: 'admin_activities', methods: ['GET'], priority: 10)]
    public function index(): Response
    {
        return new Response($this->twig->render('html/admin/page/activities.html.twig', [
            'activities' => $this->enrichedActivities->findAll(),
            'overriddenActivityIds' => array_keys($this->activityOverrideRepository->findAll()),
            'sportTypes' => SportType::cases(),
            'gears' => $this->gearRepository->findAll(),
        ]));
    }
}
