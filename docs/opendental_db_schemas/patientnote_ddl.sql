-- opendental_analytics_opendentalbackup_01_03_2025.patientnote definition

CREATE TABLE `patientnote` (
  `PatNum` bigint(20) NOT NULL,
  `FamFinancial` text DEFAULT NULL,
  `ApptPhone` text DEFAULT NULL,
  `Medical` text DEFAULT NULL,
  `Service` text DEFAULT NULL,
  `MedicalComp` text DEFAULT NULL,
  `Treatment` text DEFAULT NULL,
  `ICEName` varchar(255) NOT NULL,
  `ICEPhone` varchar(30) NOT NULL,
  `OrthoMonthsTreatOverride` int(11) NOT NULL DEFAULT -1,
  `DateOrthoPlacementOverride` date NOT NULL DEFAULT '0001-01-01',
  `SecDateTEntry` datetime NOT NULL DEFAULT '0001-01-01 00:00:00',
  `SecDateTEdit` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `Consent` tinyint(4) NOT NULL,
  `UserNumOrthoLocked` bigint(20) NOT NULL,
  `Pronoun` tinyint(4) NOT NULL,
  PRIMARY KEY (`PatNum`),
  KEY `SecDateTEntry` (`SecDateTEntry`),
  KEY `SecDateTEdit` (`SecDateTEdit`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_uca1400_ai_ci;