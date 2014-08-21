
--CloseScorePredictionMinute
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
-- Create date: 3/13/2013
-- Description:	Update Minute for closing Prediction
-- Revision: 
-- =============================================
CREATE PROCEDURE [dbo].[Chart_Admin_Update_Minute_For_Closing_Prediction]
	-- Add the parameters for the stored procedure here
	@ClosePredictionMinute INT = 80
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	UPDATE Settings
	SET VValue = CAST(@ClosePredictionMinute AS VARCHAR(10))
	WHERE VName = 'CloseScorePredictionMinute'
END