USE [bodb_LCC]
GO
/****** Object:  StoredProcedure [dbo].[Chart_Admin_Get_Event_Types]    Script Date: 8/26/2013 10:44:13 AM ******/
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
ALTER PROCEDURE [dbo].[Chart_Admin_Get_Event_Types]
	@CurrentLanguage NVARCHAR(4)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	DECLARE @NameColumn NVARCHAR(8) = 'Name',
			@SqlQuery NVARCHAR(Max)

	IF ((@CurrentLanguage IS NOT NULL) AND (@CurrentLanguage <> ''))
	BEGIN
		SET @NameColumn = @NameColumn + '_' + @CurrentLanguage
	END

	SET @SqlQuery = 'SELECT [TypeId],' + 
	                        @NameColumn + '
	                 FROM [dbo].[EventType]'

	EXEC sp_executesql @SqlQuery,
	                   N'@NameColumn NVARCHAR(7)',
					   @NameColumn
END
