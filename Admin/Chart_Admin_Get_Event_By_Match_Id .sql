USE [bodb_LCC]
GO
/****** Object:  StoredProcedure [dbo].[Chart_Admin_Get_Event_By_Match_Id]    Script Date: 8/26/2013 10:44:03 AM ******/
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
ALTER PROCEDURE [dbo].[Chart_Admin_Get_Event_By_Match_Id]
	-- Add the parameters for the stored procedure here
	@MatchId INT,
	@CurrentLanguage NVARCHAR(4)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	DECLARE @2HMinute SMALLINT,
	        @NameColumn NVARCHAR(8) = 'Name',
			@SqlQuery NVARCHAR(Max)
	SET @2HMinute = (SELECT TOP 1 [Minute]
	                 FROM [dbo].[Event] WITH(NOLOCK)
	                 WHERE ([EventType] = 203) AND ([MatchId] = @MatchId) AND isdeleted = 0)

    IF ((@CurrentLanguage IS NOT NULL) AND (@CurrentLanguage <> ''))
	BEGIN
		SET @NameColumn = @NameColumn + '_' + @CurrentLanguage
	END

	SET @SqlQuery = 'SELECT [EventId],			 
		                    [EventType],' +
		                    @NameColumn + ',
		                    [MatchId],
		                    [TeamId],	
		                    [Half] = CASE WHEN ([Minute] >= @2HMinute ) THEN 2 ELSE 1 END,
		                    [Minute] = CASE WHEN ([Minute] >= @2HMinute ) THEN ([Minute] - @2HMinute) ELSE [Minute] END,
		                    [Second],
							[Value]
	                 FROM [dbo].[Event] AS Eve WITH(NOLOCK)
	                      LEFT JOIN [dbo].[EventType] AS EventType (NOLOCK) 
						       ON (Eve.[EventType] = EventType.[TypeId])
	                 WHERE ([MatchId] = @MatchId) AND ([IsDeleted] = 0)'
	EXEC sp_executesql @SqlQuery,
	                   N'@NameColumn NVARCHAR(7), @2HMinute SMALLINT, @MatchId INT',
					   @NameColumn,
					   @2HMinute,
					   @MatchId
END
