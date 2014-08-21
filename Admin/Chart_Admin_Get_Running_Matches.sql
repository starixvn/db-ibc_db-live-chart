USE [bodb_LCC]
GO
/****** Object:  StoredProcedure [dbo].[Chart_Admin_Get_Running_Matches]    Script Date: 8/26/2013 10:45:01 AM ******/
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
ALTER PROCEDURE [dbo].[Chart_Admin_Get_Running_Matches]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT [MatchId],
		   [HomeId],
		   [AwayId],				 
		   [KickOffTime]
	FROM [Match_Queue] WITH(NOLOCK)
	WHERE ([MatchStatus] = 'running')
END
