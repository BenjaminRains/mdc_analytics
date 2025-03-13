-- opendental_analytics_opendentalbackup_01_03_2025.recall definition

CREATE TABLE `recall` (
  `RecallNum` bigint(20) NOT NULL AUTO_INCREMENT,
  `PatNum` bigint(20) NOT NULL,
  `DateDueCalc` date NOT NULL DEFAULT '0001-01-01',
  `DateDue` date NOT NULL DEFAULT '0001-01-01',
  `DatePrevious` date NOT NULL DEFAULT '0001-01-01',
  `RecallInterval` int(11) NOT NULL DEFAULT 0,
  `RecallStatus` bigint(20) NOT NULL,
  `Note` text DEFAULT NULL,
  `IsDisabled` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `DateTStamp` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `RecallTypeNum` bigint(20) NOT NULL,
  `DisableUntilBalance` double NOT NULL,
  `DisableUntilDate` date NOT NULL DEFAULT '0001-01-01',
  `DateScheduled` date NOT NULL DEFAULT '0001-01-01',
  `Priority` tinyint(4) NOT NULL,
  `TimePatternOverride` varchar(255) NOT NULL,
  PRIMARY KEY (`RecallNum`),
  KEY `PatNum` (`PatNum`),
  KEY `DatePrevious` (`DatePrevious`),
  KEY `IsDisabled` (`IsDisabled`),
  KEY `RecallTypeNum` (`RecallTypeNum`),
  KEY `DateScheduled` (`DateScheduled`),
  KEY `DateDisabledType` (`DateDue`,`IsDisabled`,`RecallTypeNum`,`DateScheduled`)
) ENGINE=MyISAM AUTO_INCREMENT=51690 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_uca1400_ai_ci;