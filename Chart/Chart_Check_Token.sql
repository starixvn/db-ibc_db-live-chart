USE [bodb_LCC]
GO
/****** Object:  StoredProcedure [dbo].[Chart_Check_Token]    Script Date: 10/2/2013 10:50:00 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-- =============================================
-- Author:		Ricky
-- Create date: 9/27/2013
-- Description:	Create
-- Revision: 
-- =============================================
*/
ALTER PROCEDURE [dbo].[Chart_Check_Token]
	-- Add the parameters for the stored procedure here
	@MemberId INT,
	@Token NVARCHAR(50),
	@IsValid BIT = 0 OUTPUT
AS
BEGIN
	
	DECLARE @CreateTime smalldatetime

	IF EXISTS ( 
		SELECT 1
		FROM AuthenticationToken WITH(NOLOCK)
		WHERE @MemberId = MemberId 
		AND @Token = Token
		AND DATEDIFF(minute, CreateTime, GETDATE()) < 2 )
		BEGIN    
			SET @IsValid = 1    		
		END 
	ELSE
		BEGIN
			SET @IsValid = 0
		END
END
