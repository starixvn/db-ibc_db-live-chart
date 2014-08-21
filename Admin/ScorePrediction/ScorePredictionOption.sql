USE [bodb_LCC]
GO

/****** Object:  Table [dbo].[ScorePredictionOption]    Script Date: 4/4/2014 1:54:13 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[ScorePredictionOption](
	[ScorePredictionOptionId] [int] IDENTITY(1,1) NOT NULL,
	[MatchId] [int] NOT NULL,
	[HomeScore] [int] NOT NULL,
	[AwayScore] [int] NOT NULL,
	[ScorePredictionCount] [int] NOT NULL,
	[DummyCount] [int] NOT NULL,
	[UpdateDummyTime] [smalldatetime] NULL,
	[AdminId] [int] NULL,
	[AdminName] [nvarchar](50) NULL,
 CONSTRAINT [PK_ScorePredictionOption] PRIMARY KEY CLUSTERED 
(
	[ScorePredictionOptionId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

ALTER TABLE [dbo].[ScorePredictionOption] ADD  CONSTRAINT [DF_ScorePredictionOption_DummyCount]  DEFAULT ((0)) FOR [DummyCount]
GO


