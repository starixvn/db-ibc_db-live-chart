USE [bodb_LCC]
GO
/****** Object:  StoredProcedure [dbo].[Chart_Admin_Update_Event]    Script Date: 8/26/2013 10:46:31 AM ******/
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
ALTER PROCEDURE [dbo].[Chart_Admin_Update_Event]
	-- Add the parameters for the stored procedure here
	@EventId INT, 
	@MatchId INT, 
	@TeamId INT,
	@EventTypeId SMALLINT,
	@Half TINYINT,
	@Minute SMALLINT,
	@Second SMALLINT,
	@Value NVARCHAR(1000) = NULL
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	DECLARE @2HMinute SMALLINT
	
	SET @2HMinute = (SELECT TOP 1 [Minute]
	                 FROM [dbo].[Event] WITH(NOLOCK)
	                 WHERE ([EventType] = 203) AND ([MatchId] = @MatchId) AND ([IsDeleted] = 0))

	UPDATE [dbo].[Event]
    SET [MatchId] = @MatchId,
        [TeamId] = @TeamId,
        [EventType] = @EventTypeId,
        [Value] = @Value,
        [Minute] = CASE WHEN (@Half = 2) THEN (@Minute + @2HMinute) ELSE @Minute END,
        [Second] = @Second
    WHERE [EventId] = @EventId
END
