<?php

declare(strict_types=1);

namespace App\Application\Activity\EditActivity;

use App\Domain\Activity\ActivityId;
use App\Domain\Activity\SportType\SportType;
use App\Domain\Gear\GearId;
use App\Infrastructure\CQRS\Command\Deserialize\AsDeserializableCommand;
use App\Infrastructure\CQRS\Command\Deserialize\CouldNotDeserializeCommand;
use App\Infrastructure\CQRS\Command\Deserialize\DeserializableCommand;
use App\Infrastructure\CQRS\Command\DomainCommand;

#[AsDeserializableCommand('edit-activity')]
final readonly class EditActivity extends DomainCommand implements DeserializableCommand
{
    private function __construct(
        private ActivityId $activityId,
        private string $name,
        private string $description,
        private SportType $sportType,
        private int $distanceInMeter,
        private int $elevationInMeter,
        private ?GearId $gearId,
        private bool $isCommute,
    ) {
    }

    public static function fromPayload(array $payload): self
    {
        if (!isset($payload['activityId'], $payload['name'], $payload['sportType'], $payload['distance'], $payload['elevation'], $payload['isCommute'])
            || !is_string($payload['activityId'])
            || !is_string($payload['name'])
            || '' === trim($payload['name'])
            || !is_string($payload['sportType'])
            || !is_numeric($payload['distance'])
            || !is_numeric($payload['elevation'])
            || !is_bool($payload['isCommute'])) {
            throw CouldNotDeserializeCommand::invalidPayload();
        }

        if (!$sportType = SportType::tryFrom($payload['sportType'])) {
            throw CouldNotDeserializeCommand::invalidPayload();
        }

        try {
            $activityId = ActivityId::fromString($payload['activityId']);
        } catch (\InvalidArgumentException) {
            throw CouldNotDeserializeCommand::invalidPayload();
        }

        $gearId = null;
        if (is_string($payload['gearId'] ?? null) && '' !== $payload['gearId']) {
            try {
                $gearId = GearId::fromString($payload['gearId']);
            } catch (\InvalidArgumentException) {
                throw CouldNotDeserializeCommand::invalidPayload();
            }
        }

        return new self(
            activityId: $activityId,
            name: trim($payload['name']),
            description: is_string($payload['description'] ?? null) ? $payload['description'] : '',
            sportType: $sportType,
            distanceInMeter: (int) round((float) $payload['distance'] * 1000),
            elevationInMeter: (int) round((float) $payload['elevation']),
            gearId: $gearId,
            isCommute: $payload['isCommute'],
        );
    }

    public function getActivityId(): ActivityId
    {
        return $this->activityId;
    }

    public function getName(): string
    {
        return $this->name;
    }

    public function getDescription(): string
    {
        return $this->description;
    }

    public function getSportType(): SportType
    {
        return $this->sportType;
    }

    public function getDistanceInMeter(): int
    {
        return $this->distanceInMeter;
    }

    public function getElevationInMeter(): int
    {
        return $this->elevationInMeter;
    }

    public function getGearId(): ?GearId
    {
        return $this->gearId;
    }

    public function isCommute(): bool
    {
        return $this->isCommute;
    }
}
