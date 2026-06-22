<?php

declare(strict_types=1);

namespace App\Application\Activity\RevertActivityOverride;

use App\Domain\Activity\ActivityOverride\ActivityOverrideRepository;
use App\Infrastructure\CQRS\Command\Command;
use App\Infrastructure\CQRS\Command\CommandHandler;

final readonly class RevertActivityOverrideCommandHandler implements CommandHandler
{
    public function __construct(
        private ActivityOverrideRepository $activityOverrideRepository,
    ) {
    }

    public function handle(Command $command): void
    {
        assert($command instanceof RevertActivityOverride);

        $this->activityOverrideRepository->delete($command->getActivityId());
    }
}
