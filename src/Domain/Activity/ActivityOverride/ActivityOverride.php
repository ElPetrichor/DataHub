<?php

declare(strict_types=1);

namespace App\Domain\Activity\ActivityOverride;

use App\Domain\Activity\ActivityId;
use App\Domain\Activity\SportType\SportType;
use App\Domain\Gear\GearId;
use App\Infrastructure\ValueObject\Time\SerializableDateTime;

final readonly class ActivityOverride
{
    private function __construct(
        private ActivityId $activityId,
        private ?string $name,
        private ?string $description,
        private ?SportType $sportType,
        private ?int $distanceInMeter,
        private ?int $elevationInMeter,
        private ?GearId $gearId,
        private ?bool $isCommute,
        private SerializableDateTime $updatedAt,
    ) {
    }

    public static function fromState(
        ActivityId $activityId,
        ?string $name,
        ?string $description,
        ?SportType $sportType,
        ?int $distanceInMeter,
        ?int $elevationInMeter,
        ?GearId $gearId,
        ?bool $isCommute,
        SerializableDateTime $updatedAt,
    ): self {
        return new self(
            activityId: $activityId,
            name: $name,
            description: $description,
            sportType: $sportType,
            distanceInMeter: $distanceInMeter,
            elevationInMeter: $elevationInMeter,
            gearId: $gearId,
            isCommute: $isCommute,
            updatedAt: $updatedAt,
        );
    }

    public function getActivityId(): ActivityId
    {
        return $this->activityId;
    }

    public function getName(): ?string
    {
        return $this->name;
    }

    public function getDescription(): ?string
    {
        return $this->description;
    }

    public function getSportType(): ?SportType
    {
        return $this->sportType;
    }

    public function getDistanceInMeter(): ?int
    {
        return $this->distanceInMeter;
    }

    public function getElevationInMeter(): ?int
    {
        return $this->elevationInMeter;
    }

    public function getGearId(): ?GearId
    {
        return $this->gearId;
    }

    public function getIsCommute(): ?bool
    {
        return $this->isCommute;
    }

    public function getUpdatedAt(): SerializableDateTime
    {
        return $this->updatedAt;
    }

    /**
     * Overlays the non-null override fields onto a raw Activity DB row, leaving
     * everything else as the original Strava-imported value.
     *
     * @param array<string, mixed> $row
     *
     * @return array<string, mixed>
     */
    public function overlayOnto(array $row): array
    {
        foreach ([
            'name' => $this->name,
            'description' => $this->description,
            'sportType' => $this->sportType?->value,
            'distance' => $this->distanceInMeter,
            'elevation' => $this->elevationInMeter,
            'gearId' => $this->gearId,
            'isCommute' => $this->isCommute,
        ] as $column => $value) {
            if (null !== $value) {
                $row[$column] = $value;
            }
        }

        return $row;
    }
}
