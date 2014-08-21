USE [bodb_LCC]
GO
/****** Object:  StoredProcedure [dbo].[Chart_Admin_Get_Leagues]    Script Date: 8/26/2013 10:44:30 AM ******/
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
ALTER PROCEDURE [dbo].[Chart_Admin_Get_Leagues]
	-- Add the parameters for the stored procedure here
	@MatchDate DATETIME = NULL,
	@SportId INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT DISTINCT [Temp].[LeagueId]
	FROM (SELECT [LeagueId]
		  FROM [dbo].[Match] WITH(NOLOCK)
		  WHERE abs(datediff(d, [EventDate] , @MatchDate)) = 0
		 UNION ALL
		  SELECT [LeagueId]
		  FROM [dbo].[Match_Queue] WITH(NOLOCK)
		  WHERE abs(datediff(d, [EventDate] , @MatchDate)) = 0
		 UNION ALL
		  SELECT [LeagueId]
		  FROM [bodb02].[dbo].[Match] WITH(NOLOCK)
		  WHERE abs(datediff(d, [EventDate] , @MatchDate)) = 0 AND ([SportType] = @SportId) AND eventstatus = 'running'
	     ) AS Temp
END
