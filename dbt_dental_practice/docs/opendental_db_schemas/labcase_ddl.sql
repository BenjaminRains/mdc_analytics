-- opendental_analytics_opendentalbackup_01_03_2025.labcase definition

CREATE TABLE `labcase` (
  `LabCaseNum` bigint(20) NOT NULL AUTO_INCREMENT,
  `PatNum` bigint(20) NOT NULL,
  `LaboratoryNum` bigint(20) NOT NULL,
  `AptNum` bigint(20) NOT NULL,
  `PlannedAptNum` bigint(20) NOT NULL,
  `DateTimeDue` datetime NOT NULL DEFAULT '0001-01-01 00:00:00',
  `DateTimeCreated` datetime NOT NULL DEFAULT '0001-01-01 00:00:00',
  `DateTimeSent` datetime NOT NULL DEFAULT '0001-01-01 00:00:00',
  `DateTimeRecd` datetime NOT NULL DEFAULT '0001-01-01 00:00:00',
  `DateTimeChecked` datetime NOT NULL DEFAULT '0001-01-01 00:00:00',
  `ProvNum` bigint(20) NOT NULL,
  `Instructions` text DEFAULT NULL,
  `LabFee` double NOT NULL,
  `DateTStamp` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `InvoiceNum` varchar(255) NOT NULL,
  PRIMARY KEY (`LabCaseNum`),
  KEY `indexAptNum` (`AptNum`)
) ENGINE=MyISAM AUTO_INCREMENT=4439 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_uca1400_ai_ci;