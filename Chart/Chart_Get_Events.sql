USE [bodb_LCC]
GO
/****** Object:  StoredProcedure [dbo].[Chart_Get_Events]    Script Date: 9/9/2013 9:35:38 AM ******/
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
ALTER PROCEDURE [dbo].[Chart_Get_Events]
	-- Add the parameters for the stored procedure here
	@MatchId int, 
	@Minute smallint,
	@MaxTime nvarchar(50) = '' OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	EXEC dbo.Chart_Get_Max_Time 1, @MaxTime OUTPUT 
	SELECT e.teamid, e.minute, e.value, et.name, e.eventtype
	FROM dbo.[Event] as e, eventtype as et WITH(NOLOCK)
	WHERE e.[MatchId] = @MatchId
	AND e.[Minute] > @Minute
	AND e.eventtype = et.typeid
	AND e.isdeleted = 0
	ORDER BY [Minute] 
END