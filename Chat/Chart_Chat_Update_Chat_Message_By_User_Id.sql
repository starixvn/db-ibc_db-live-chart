-- ================================================
-- Template generated from Template Explorer using:
-- Create Procedure (New Menu).SQL
--
-- Use the Specify Values for Template Parameters 
-- command (Ctrl-Shift-M) to fill in the parameter 
-- values below.
--
-- This block of comments will not be included in
-- the definition of the procedure.
-- ================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ricky
-- Create date: 03/17/2014
-- Description:	Get Chat Message by Chart User
-- =============================================
CREATE PROCEDURE Chart_Chat_Update_Chat_Message_By_User_Id
	@ChatRoomId INT,
	@ChatUserId INT,
	@IsDeleted BIT = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT ChatMessageId, ChatUserId, Content, CreateTime
	FROM ChatMessage (NOLOCK) 
	WHERE ChatRoomId = @ChatRoomId AND ChatUserId = @ChatUserId AND IsDeleted = @IsDeleted
END
GO
