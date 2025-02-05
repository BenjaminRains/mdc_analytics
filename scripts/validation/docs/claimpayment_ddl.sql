-- opendental_analytics_opendentalbackup_01_03_2025.claimpayment definition

CREATE TABLE `claimpayment` (
  `ClaimPaymentNum` bigint(20) NOT NULL AUTO_INCREMENT,
  `CheckDate` date NOT NULL DEFAULT '0001-01-01',
  `CheckAmt` double NOT NULL DEFAULT 0,
  `CheckNum` varchar(25) DEFAULT '',
  `BankBranch` varchar(25) DEFAULT '',
  `Note` varchar(255) DEFAULT '',
  `ClinicNum` bigint(20) NOT NULL,
  `DepositNum` bigint(20) NOT NULL,
  `CarrierName` varchar(255) DEFAULT '',
  `DateIssued` date NOT NULL DEFAULT '0001-01-01',
  `IsPartial` tinyint(4) NOT NULL,
  `PayType` bigint(20) NOT NULL,
  `SecUserNumEntry` bigint(20) NOT NULL,
  `SecDateEntry` date NOT NULL DEFAULT '0001-01-01',
  `SecDateTEdit` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `PayGroup` bigint(20) NOT NULL,
  PRIMARY KEY (`ClaimPaymentNum`),
  KEY `DepositNum` (`DepositNum`),
  KEY `PayType` (`PayType`),
  KEY `SecUserNumEntry` (`SecUserNumEntry`),
  KEY `CheckDate` (`CheckDate`),
  KEY `PayGroup` (`PayGroup`),
  KEY `ClinicNum` (`ClinicNum`)
) ENGINE=MyISAM AUTO_INCREMENT=18563 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_uca1400_ai_ci;