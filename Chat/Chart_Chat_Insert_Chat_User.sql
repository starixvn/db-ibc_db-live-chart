USE [bodb_LCC]
GO
/****** Object:  StoredProcedure [dbo].[Chart_Chat_Insert_Chat_User]    Script Date: 05/06/2014 09:15:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ricky.Nguyen
-- Create date: 03/17/2014
-- Description: Insert new chat user.	
-- Revision:
			--+ 05/20/2014: Update Get Member Banned by default
-- =============================================

ALTER PROCEDURE [dbo].[Chart_Chat_Insert_Chat_User]
	@MemberId		INT,
	@ChatName		NVARCHAR(50),
	@IsBanned		BIT = 0,
	@ChatUserId		INT = 0 OUTPUT,
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(100) = 0 OUTPUT
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	IF(EXISTS(SELECT TOP 1 * FROM ChatUser (NOLOCK) WHERE ChatName = @ChatName))
		BEGIN
			SET @ErrCode = 1001
			SET @ErrMsg = 'This Chat Name does not available, please choose another one.'
			RETURN
		END

	IF(EXISTS(SELECT TOP 1 * FROM ChatUser (NOLOCK) WHERE MemberId = @MemberId))
		BEGIN
			SET @ErrCode = 1002
			SET @ErrMsg = 'You already have Chat Name.'
			RETURN
		END
		
	IF(EXISTS(SELECT TOP 1 * FROM MemberBanned (NOLOCK) WHERE MemberId = @MemberId AND IsBanned = 1))
		BEGIN
			SET @ErrCode = 1003
			SET @ErrMsg = 'Sorry, this room is not available.'
			RETURN
		END
	
	DECLARE @MemberName NVARCHAR(50) = '---'
	SELECT @MemberName = ISNULL(username, '---')
	FROM bodb02.dbo.custInfo WITH (NOLOCK)
	WHERE @MemberId = custid

	INSERT INTO ChatUser([ChatName], [MemberId], [CreateTime], [ModifiedTime], [IsBanned], [AgreedTerms], [MemberName])
	VALUES(@ChatName, @MemberId, GETDATE(), GETDATE(), @IsBanned, 0, @MemberName)
	SET @ChatUserId = SCOPE_IDENTITY();

END

