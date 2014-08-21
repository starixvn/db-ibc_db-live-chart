USE [bodb_LCC]
GO
/****** Object:  StoredProcedure [dbo].[Chart_Admin_Get_Match_By_Id]    Script Date: 8/26/2013 10:44:50 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ricky
-- Create date: 6/25/2013
-- Description:	Create
-- Revision: 
-- =============================================
ALTER PROCEDURE [dbo].[Chart_Admin_Get_Match_By_Id]
	-- Add the parameters for the stored procedure here
	@MatchId INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT [MatchId],
           [HomeId],
           [AwayId],
		   [KickOffTime],
		   [ChartEnabled]
	FROM (SELECT [MatchId],
				 [HomeId],
				 [AwayId],
				 [KickOffTime],
				 CAST(1 AS BIT) AS ChartEnabled
          FROM [dbo].[Match_Queue]  WITH(NOLOCK)
		 UNION 
		  SELECT [MatchId],
		         [HomeId],
				 [AwayId],
				 [KickOffTime],
				 [IsMonitor] AS ChartEnabled
		  FROM [dbo].[Match] WITH(NOLOCK)
		 UNION 
		  SELECT [MatchId],
		         [HomeId],
				 [AwayId],
				 [KickOffTime],
				 CAST(0 AS BIT) AS ChartEnabled
		 FROM [bodb02].[dbo].[Match] WITH(NOLOCK)) AS Teamp
	WHERE [MatchId] = @MatchId
END
