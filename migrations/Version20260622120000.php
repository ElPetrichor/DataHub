<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20260622120000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Add ActivityOverride table to support manually editing imported activities without losing the edits on the next Strava sync.';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('CREATE TABLE ActivityOverride (activityId VARCHAR(255) NOT NULL, name VARCHAR(255) DEFAULT NULL, description CLOB DEFAULT NULL, sportType VARCHAR(255) DEFAULT NULL, distance INTEGER DEFAULT NULL, elevation INTEGER DEFAULT NULL, gearId VARCHAR(255) DEFAULT NULL, isCommute BOOLEAN DEFAULT NULL, updatedAt DATETIME NOT NULL, PRIMARY KEY (activityId))');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('DROP TABLE ActivityOverride');
    }
}