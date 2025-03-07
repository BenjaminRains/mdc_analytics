-- opendental_analytics_opendentalbackup_01_03_2025.insbluebook definition

CREATE TABLE `insbluebook` (
  `InsBlueBookNum` bigint(20) NOT NULL AUTO_INCREMENT,
  `ProcCodeNum` bigint(20) NOT NULL,
  `CarrierNum` bigint(20) NOT NULL,
  `PlanNum` bigint(20) NOT NULL,
  `GroupNum` varchar(25) NOT NULL,
  `InsPayAmt` double NOT NULL,
  `AllowedOverride` double NOT NULL,
  `DateTEntry` datetime NOT NULL DEFAULT '0001-01-01 00:00:00',
  `ProcNum` bigint(20) NOT NULL,
  `ProcDate` date NOT NULL DEFAULT '0001-01-01',
  `ClaimType` varchar(10) NOT NULL,
  `ClaimNum` bigint(20) NOT NULL,
  PRIMARY KEY (`InsBlueBookNum`),
  KEY `ProcCodeNum` (`ProcCodeNum`),
  KEY `CarrierNum` (`CarrierNum`),
  KEY `PlanNum` (`PlanNum`),
  KEY `ProcNum` (`ProcNum`),
  KEY `ClaimNum` (`ClaimNum`)
) ENGINE=MyISAM AUTO_INCREMENT=50741 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_uca1400_ai_ci;