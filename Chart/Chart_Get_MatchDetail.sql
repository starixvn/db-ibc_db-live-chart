USE [bodb_LCC]
GO
/****** Object:  StoredProcedure [dbo].[Chart_Get_MatchDetail]    Script Date: 8/26/2013 10:49:40 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ricky
-- Create date: 7/17/2013
-- Description:	Create
-- Revision: 
-- =============================================
ALTER PROCEDURE [dbo].[Chart_Get_MatchDetail]
	@MatchId int = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT [matchid]
			,[leagueid]
			,[homeid]
			,[awayid]
			,[eventdate]
			,[kickofftime]
	FROM match WITH(NOLOCK)
	WHERE @MatchId = matchid
	UNION ALL
	SELECT [matchid]
			,[leagueid]
			,[homeid]
			,[awayid]
			,[eventdate]
			,[kickofftime]
	FROM [dbo].[match_queue] WITH(NOLOCK)
	WHERE @MatchId = matchid
END