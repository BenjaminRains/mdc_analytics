-- opendental_analytics_opendentalbackup_01_03_2025.insverifyhist definition

CREATE TABLE `insverifyhist` (
  `InsVerifyHistNum` bigint(20) NOT NULL AUTO_INCREMENT,
  `InsVerifyNum` bigint(20) NOT NULL,
  `DateLastVerified` date NOT NULL DEFAULT '0001-01-01',
  `UserNum` bigint(20) NOT NULL,
  `VerifyType` tinyint(4) NOT NULL,
  `FKey` bigint(20) NOT NULL,
  `DefNum` bigint(20) NOT NULL,
  `Note` text NOT NULL,
  `DateLastAssigned` date NOT NULL DEFAULT '0001-01-01',
  `DateTimeEntry` datetime NOT NULL DEFAULT '0001-01-01 00:00:00',
  `HoursAvailableForVerification` double NOT NULL,
  `VerifyUserNum` bigint(20) NOT NULL,
  `SecDateTEdit` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`InsVerifyHistNum`),
  KEY `InsVerifyNum` (`InsVerifyNum`),
  KEY `UserNum` (`UserNum`),
  KEY `FKey` (`FKey`),
  KEY `DefNum` (`DefNum`),
  KEY `VerifyUserNum` (`VerifyUserNum`),
  KEY `SecDateTEdit` (`SecDateTEdit`)
) ENGINE=MyISAM AUTO_INCREMENT=34452 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_uca1400_ai_ci;