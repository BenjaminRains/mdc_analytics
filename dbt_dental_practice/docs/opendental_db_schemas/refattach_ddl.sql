-- opendental_analytics_opendentalbackup_01_03_2025.refattach definition

CREATE TABLE `refattach` (
  `RefAttachNum` bigint(20) NOT NULL AUTO_INCREMENT,
  `ReferralNum` bigint(20) NOT NULL,
  `PatNum` bigint(20) NOT NULL,
  `ItemOrder` smallint(5) unsigned NOT NULL DEFAULT 0,
  `RefDate` date NOT NULL DEFAULT '0001-01-01',
  `RefType` tinyint(4) NOT NULL,
  `RefToStatus` tinyint(3) unsigned NOT NULL,
  `Note` text DEFAULT NULL,
  `IsTransitionOfCare` tinyint(4) NOT NULL,
  `ProcNum` bigint(20) NOT NULL,
  `DateProcComplete` date NOT NULL DEFAULT '0001-01-01',
  `ProvNum` bigint(20) NOT NULL,
  `DateTStamp` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`RefAttachNum`),
  KEY `PatNum` (`PatNum`),
  KEY `ProcNum` (`ProcNum`),
  KEY `ProvNum` (`ProvNum`),
  KEY `ReferralNum` (`ReferralNum`)
) ENGINE=MyISAM AUTO_INCREMENT=7516 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_uca1400_ai_ci;