-- opendental_analytics_opendentalbackup_01_03_2025.commlog definition

CREATE TABLE `commlog` (
  `CommlogNum` bigint(20) NOT NULL AUTO_INCREMENT,
  `PatNum` bigint(20) NOT NULL,
  `CommDateTime` datetime NOT NULL DEFAULT '0001-01-01 00:00:00',
  `CommType` bigint(20) NOT NULL,
  `Note` text DEFAULT NULL,
  `Mode_` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `SentOrReceived` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `UserNum` bigint(20) NOT NULL,
  `Signature` text NOT NULL,
  `SigIsTopaz` tinyint(4) NOT NULL,
  `DateTStamp` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `DateTimeEnd` datetime NOT NULL DEFAULT '0001-01-01 00:00:00',
  `CommSource` tinyint(4) DEFAULT NULL,
  `ProgramNum` bigint(20) NOT NULL,
  `DateTEntry` datetime NOT NULL DEFAULT '0001-01-01 00:00:00',
  `ReferralNum` bigint(20) NOT NULL,
  `CommReferralBehavior` tinyint(4) NOT NULL,
  PRIMARY KEY (`CommlogNum`),
  KEY `PatNum` (`PatNum`),
  KEY `CommDateTime` (`CommDateTime`),
  KEY `CommType` (`CommType`),
  KEY `ProgramNum` (`ProgramNum`),
  KEY `indexPNCDateCType` (`PatNum`,`CommDateTime`,`CommType`),
  KEY `UserNum` (`UserNum`),
  KEY `ReferralNum` (`ReferralNum`),
  KEY `idx_commlog_type_note` (`PatNum`,`CommType`,`Note`(20)),
  KEY `idx_commlog_patient_date` (`PatNum`,`CommDateTime`,`CommType`)
) ENGINE=MyISAM AUTO_INCREMENT=766882 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_uca1400_ai_ci;