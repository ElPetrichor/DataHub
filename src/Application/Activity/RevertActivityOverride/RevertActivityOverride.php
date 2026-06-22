<?php

declare(strict_types=1);

namespace App\Application\Activity\RevertActivityOverride;

use App\Domain\Activity\ActivityId;
use App\Infrastructure\CQRS\Command\Deserialize\AsDeserializableCommand;
use App\Infrastructure\CQRS\Command\Deserialize\CouldNotDeserializeCommand;
use App\Infrastructure\CQRS\Command\Deserialize\DeserializableCommand;
use App\Infrastructure\CQRS\Command\DomainCommand;

#[AsDeserializableCommand('revert-activity-override')]
final readonly class RevertActivityOverride extends DomainCommand implements DeserializableCommand
{
    private function __construct(
        private ActivityId $activityId,
    ) {
    }

    public static function fromPayload(array $payload): self
    {
        if (!isset($payload['activityId']) || !is_string($payload['activityId'])) {
            throw CouldNotDeserializeCommand::invalidPayload();
        }

        try {
            $activityId = ActivityId::fromString($payload['activityId']);
        } catch (\InvalidArgumentException) {
            throw CouldNotDeserializeCommand::invalidPayload();
        }

        return new self($activityId);
    }

    public function getActivityId(): ActivityId
    {
        return $this->activityId;
    }
}
