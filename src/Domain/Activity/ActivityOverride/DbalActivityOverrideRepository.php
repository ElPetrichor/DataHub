<?php

declare(strict_types=1);

namespace App\Domain\Activity\ActivityOverride;

use App\Domain\Activity\ActivityId;
use App\Domain\Activity\SportType\SportType;
use App\Domain\Gear\GearId;
use App\Infrastructure\Repository\DbalRepository;
use App\Infrastructure\ValueObject\Time\SerializableDateTime;

final readonly class DbalActivityOverrideRepository extends DbalRepository implements ActivityOverrideRepository
{
    public function find(ActivityId $activityId): ?ActivityOverride
    {
        $queryBuilder = $this->connection->createQueryBuilder();
        $queryBuilder->select('*')
            ->from('ActivityOverride')
            ->andWhere('activityId = :activityId')
            ->setParameter('activityId', $activityId);

        if (!$result = $queryBuilder->executeQuery()->fetchAssociative()) {
            return null;
        }

        return $this->hydrate($result);
    }

    public function findAll(): array
    {
        $results = $this->connection->executeQuery('SELECT * FROM ActivityOverride')->fetchAllAssociative();

        $overrides = [];
        foreach ($results as $result) {
            $override = $this->hydrate($result);
            $overrides[(string) $override->getActivityId()] = $override;
        }

        return $overrides;
    }

    public function save(ActivityOverride $activityOverride): void
    {
        $sql = 'INSERT INTO ActivityOverride (activityId, name, description, sportType, distance, elevation, gearId, isCommute, updatedAt)
                VALUES (:activityId, :name, :description, :sportType, :distance, :elevation, :gearId, :isCommute, :updatedAt)
                ON CONFLICT(activityId) DO UPDATE SET
                    name = excluded.name,
                    description = excluded.description,
                    sportType = excluded.sportType,
                    distance = excluded.distance,
                    elevation = excluded.elevation,
                    gearId = excluded.gearId,
                    isCommute = excluded.isCommute,
                    updatedAt = excluded.updatedAt';

        $this->connection->executeStatement($sql, [
            'activityId' => $activityOverride->getActivityId(),
            'name' => $activityOverride->getName(),
            'description' => $activityOverride->getDescription(),
            'sportType' => $activityOverride->getSportType()?->value,
            'distance' => $activityOverride->getDistanceInMeter(),
            'elevation' => $activityOverride->getElevationInMeter(),
            'gearId' => $activityOverride->getGearId(),
            'isCommute' => null === $activityOverride->getIsCommute() ? null : (int) $activityOverride->getIsCommute(),
            'updatedAt' => $activityOverride->getUpdatedAt(),
        ]);
    }

    public function delete(ActivityId $activityId): void
    {
        $this->connection->executeStatement(
            'DELETE FROM ActivityOverride WHERE activityId = :activityId',
            ['activityId' => $activityId]
        );
    }

    /**
     * @param array<string, mixed> $result
     */
    private function hydrate(array $result): ActivityOverride
    {
        return ActivityOverride::fromState(
            activityId: ActivityId::fromString($result['activityId']),
            name: $result['name'],
            description: $result['description'],
            sportType: isset($result['sportType']) ? SportType::from($result['sportType']) : null,
            distanceInMeter: isset($result['distance']) ? (int) $result['distance'] : null,
            elevationInMeter: isset($result['elevation']) ? (int) $result['elevation'] : null,
            gearId: GearId::fromOptionalString($result['gearId']),
            isCommute: isset($result['isCommute']) ? (bool) $result['isCommute'] : null,
            updatedAt: SerializableDateTime::fromString($result['updatedAt']),
        );
    }
}