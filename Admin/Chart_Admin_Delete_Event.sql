USE [bodb_LCC]
GO
/****** Object:  StoredProcedure [dbo].[Chart_Admin_Delete_Event]    Script Date: 8/26/2013 10:42:13 AM ******/
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
ALTER PROCEDURE [dbo].[Chart_Admin_Delete_Event]
	-- Add the parameters for the stored procedure here
	@EventId BIGINT,
	@IsDeleted BIT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	UPDATE [dbo].[Event]
	SET [IsDeleted] = @IsDeleted
    WHERE [EventId] = @EventId
END
