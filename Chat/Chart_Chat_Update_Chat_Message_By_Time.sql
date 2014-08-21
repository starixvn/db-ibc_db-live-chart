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
-- Description:	Get Chat Message by time
-- =============================================
ALTER PROCEDURE Chart_Chat_Update_Chat_Message_By_Time
	@ChatRoomId INT,
	@FromTime SMALLDATETIME,
	@ToTime SMALLDATETIME
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT cm.ChatMessageId, cm.ChatUserId, cu.ChatName, cm.Content, cm.CreateTime
	FROM ChatMessage (NOLOCK) AS cm JOIN ChatUser (NOLOCK) AS cu ON cm.ChatUserId = cu.ChatUserId
	WHERE cm.ChatRoomId = @ChatRoomId AND cm.IsDeleted = 0 AND cm.CreateTime BETWEEN @FromTime AND @ToTime
END
GO
