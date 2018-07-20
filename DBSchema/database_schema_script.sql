USE [bodb_OIC]
GO
/****** Object:  StoredProcedure [dbo].[DBA_GrantPermissions]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE PROCEDURE [dbo].[DBA_GrantPermissions] 
            @SPs			nvarchar(4000), 
            @strPermission	varchar(4000)='' OUTPUT 
            AS 
             BEGIN 
             SET NOCOUNT ON; 
            DECLARE @SP_name nvarchar(4000), @i int, @StringPermission nvarchar(4000) 
             SELECT @SPs = @SPs + ',' , @strPermission ='GO nnn' 
             SELECT @SPs = replace(@SPs, ',,', ',') 
             SELECT @i = charindex(',', @SPs) 
             WHILE @i > 0 
            BEGIN 
             SELECT @SP_name = left(@SPs, @I-1) 
             SELECT @SPs = replace(@SPs, @SP_name + ',', '') 
             SELECT @strPermission = @strPermission + ' ' + state_desc + ' '+ permission_name + ' ON ' +  '[dbo].[' + OBJECT_NAME(major_id)  + ']' + ' TO '+ '['+ USER_NAME(grantee_principal_id)+']' + 'nnnGO nnn' 
             FROM sys.database_permissions 
            WHERE OBJECT_NAME(major_id)= @SP_Name 
            SELECT @i = charindex(',', @SPs) 
            END 
            Select @strPermission 
            END
GO
/****** Object:  StoredProcedure [dbo].[NAP_SpecialDelete_VoidByCurrency_SelectLicensees_UAT1]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[NAP_SpecialDelete_VoidByCurrency_SelectLicensees_UAT1]
AS
/*
	Created: Alan
	Date: 20180627
	DB: DBOIC/bodb_OIC  

	Revisions:
		- 20180627@Alan: Mapping China Markets Option for Void By Currency - Special Delete [97393]
*/
BEGIN
SET NOCOUNT ON

	DECLARE @MBCGroup_Id		 INT		  = -1
		  , @MBCGroup_Name		 VARCHAR(100) = 'MBC Group'
		  , @789y_Id			 INT		  = 0
		  , @789y_Name			 VARCHAR(100) = '789y'
		  , @Others_GroupName	 VARCHAR(100) = 'Others'
		  , @China_GroupName	 VARCHAR(100) = 'China rules'
		  , @Asia_GroupName		 VARCHAR(100) = 'Asia rules'

	CREATE TABLE #LicenseeGroupInfo
	(
		Id INT,
		Name VARCHAR(100) PRIMARY KEY,
		GroupName VARCHAR(100)
	)

	INSERT INTO #LicenseeGroupInfo (Id, Name, GroupName)
	VALUES (@MBCGroup_Id, @MBCGroup_Name, @Others_GroupName)
	, (@789y_Id, @789y_Name, @Others_GroupName)

	INSERT INTO #LicenseeGroupInfo (Id, Name, GroupName)
	SELECT
		LicenseeId AS Id
	   ,LicenseeName AS Name
	   ,CASE WHEN IsChineseMarketOnly = 1 THEN @China_GroupName
			ELSE @Asia_GroupName END AS GroupName
	FROM dbo.Licensee WITH(NOLOCK)
	WHERE LicenseeStatusId = 3

	SELECT Id ,Name ,GroupName
	FROM #LicenseeGroupInfo
	ORDER BY CASE GroupName
		WHEN @China_GroupName THEN 1
		WHEN @Asia_GroupName THEN 2
		ELSE 3	END ASC	,Name ASC

	SET NOCOUNT OFF
	DROP TABLE #LicenseeGroupInfo
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_AmendmentNotificationListSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_AmendmentNotificationListSel    Script Date: 5/24/2018 10:46:21 PM ******/
CREATE PROCEDURE [dbo].[OIC_AmendmentNotificationListSel]
	@FromDate			DATETIME,
	@ToDate				DATETIME, 
	@AmendmentStatus	INT	 			=  -1,
	@SelectedLanguage	VARCHAR(10)		= 'En',		
	@SelectedSiteNames	VARCHAR(MAX)	= 'All',
	@UserId				INT,
	@PageSize			INT				= 10,
	@PageIndex			INT				= 0,
	@TotalRecords		INT				= 0	OUTPUT
AS
/*
	Created by: Scofield
	Date: 20171017 [#84004]
	DB: DBOIC.bodb_OIC
	
	Revisions:	
		- 20171030@Scofield: #84004 - Implement Deliver notification to licensee backend
		- 20180123@Scofield: #89901 - Enhance Result Notification function : sorting records, update @SelectedSiteNames
		- 20180202@Scofield: #90464 - Add PublishedDate

	Param's Explanation:
		@@AmendmentStatus: -1: All, 0: New, 1: Active, 2: Inactive		
 */
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RowStart	INT,
			@RowEnd	INT
	DECLARE @tblTicketBySites TABLE (MessageID INT)
	
	SELECT	@PageIndex   = @PageIndex, 
			@RowStart	 = @PageSize * @PageIndex + 1,
			@RowEnd	     = @RowStart + @PageSize - 1
			
	DECLARE @messageResult TABLE (
		MessageId 	INT, 
		Subject 		NVARCHAR(MAX), 
		Content 		NVARCHAR(MAX), 
		Status		INT,
		EventDate	DateTime,
		PublishedDate	DateTime,
		TotalRecords	INT)	
	
	IF @SelectedSiteNames <> 'All'
	BEGIN
		INSERT INTO @tblTicketBySites(MessageID)
		SELECT DISTINCT MessageID
		FROM dbo.AmendmentTicket
		WHERE LicenseeName IN (SELECT val FROM dbo.strSplit(@SelectedSiteNames, ','))			
	END
		
	;WITH tempMessage AS
	(SELECT ROW_NUMBER() OVER(ORDER BY EventDate DESC, MessageID DESC) AS RowNumber, MessageId, Status, EventDate, PublishedDate,
		CASE WHEN @SelectedLanguage = 'Ch' AND ISNULL(SubjectCh, '') <> '' THEN SubjectCh
				WHEN @SelectedLanguage = 'Cs' AND ISNULL(SubjectCs, '') <> '' THEN SubjectCs
				ELSE SubjectEn 
				END AS Subject,
		CASE WHEN @SelectedLanguage = 'Ch' AND ISNULL(ContentCh, '') <> '' THEN ContentCh
			WHEN @SelectedLanguage = 'Cs' AND ISNULL(ContentCs, '') <> '' THEN ContentCs
			ELSE ContentEn
			END AS Content	
	FROM dbo.AmendmentMessage WITH(NOLOCK)
	WHERE (@AmendmentStatus = -1 OR Status = @AmendmentStatus) 
		AND (EventDate BETWEEN @FromDate AND @ToDate)
		AND IsTest = 0
		AND (@SelectedSiteNames = 'All' OR (MessageID IN (SELECT MessageID FROM @tblTicketBySites)))
	)
	
	INSERT INTO @messageResult (MessageId, Subject, Content, Status, EventDate, PublishedDate, TotalRecords)		
	SELECT tmp.MessageId, tmp.Subject, tmp.Content, tmp.Status, tmp.EventDate, tmp.PublishedDate,
		(SELECT MAX(RowNumber) FROM tempMessage) AS TotalRecords
	FROM tempMessage tmp		
	WHERE tmp.RowNumber BETWEEN @RowStart AND @RowEnd
	ORDER BY tmp.EventDate DESC
	
	-- Select Results
	SELECT MessageId, Subject, Content, Status, EventDate, PublishedDate
	FROM @messageResult
	
	SELECT TicketId, MessageId, LicenseeName AS SiteName, DataFilePath
	FROM dbo.AmendmentTicket WITH(NOLOCK)
	WHERE MessageId IN (SELECT MessageId FROM @messageResult)		
	
	SET @TotalRecords = (SELECT TOP 1 TotalRecords FROM @messageResult)
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_AmendmentNotificationListSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OIC_AmendmentNotificationListSel_xtest]
	@FromDate			DATETIME,
	@ToDate				DATETIME, 
	@AmendmentStatus	INT	 			=  -1,
	@SelectedLanguage	VARCHAR(10)		= 'En',		
	@SelectedSiteNames	VARCHAR(MAX)	= 'All',
	@UserId				INT,
	@PageSize			INT				= 10,
	@PageIndex			INT				= 0,
	@TotalRecords		INT				= 0	OUTPUT
AS
/*
	Created by: Scofield
	Date: 20171017 [#84004]
	DB: DBOIC.bodb_OIC
	
	Revisions:	
		- 20171030@Scofield: #84004 - Implement Deliver notification to licensee backend
		- 20180123@Scofield: #89901 - Enhance Result Notification function : sorting records, update @SelectedSiteNames
		- 20180202@Scofield: #90464 - Add PublishedDate

	Param's Explanation:
		@@AmendmentStatus: -1: All, 0: New, 1: Active, 2: Inactive		
 */
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RowStart	INT,
			@RowEnd	INT
	DECLARE @tblTicketBySites TABLE (MessageID INT)
	
	SELECT	@PageIndex   = @PageIndex, 
			@RowStart	 = @PageSize * @PageIndex + 1,
			@RowEnd	     = @RowStart + @PageSize - 1
			
	DECLARE @messageResult TABLE (
		MessageId 	INT, 
		Subject 		NVARCHAR(MAX), 
		Content 		NVARCHAR(MAX), 
		Status		INT,
		EventDate	DateTime,
		PublishedDate	DateTime,
		TotalRecords	INT)	
	
	IF @SelectedSiteNames <> 'All'
	BEGIN
		INSERT INTO @tblTicketBySites(MessageID)
		SELECT DISTINCT MessageID
		FROM dbo.AmendmentTicket
		WHERE LicenseeName IN (SELECT val FROM dbo.strSplit(@SelectedSiteNames, ','))			
	END
		
	;WITH tempMessage AS
	(SELECT ROW_NUMBER() OVER(ORDER BY EventDate DESC, MessageID DESC) AS RowNumber, MessageId, Status, EventDate, PublishedDate,
		CASE WHEN @SelectedLanguage = 'Ch' AND ISNULL(SubjectCh, '') <> '' THEN SubjectCh
				WHEN @SelectedLanguage = 'Cs' AND ISNULL(SubjectCs, '') <> '' THEN SubjectCs
				ELSE SubjectEn 
				END AS Subject,
		CASE WHEN @SelectedLanguage = 'Ch' AND ISNULL(ContentCh, '') <> '' THEN ContentCh
			WHEN @SelectedLanguage = 'Cs' AND ISNULL(ContentCs, '') <> '' THEN ContentCs
			ELSE ContentEn
			END AS Content	
	FROM dbo.AmendmentMessage WITH(NOLOCK)
	WHERE (@AmendmentStatus = -1 OR Status = @AmendmentStatus) 
		AND (EventDate BETWEEN @FromDate AND @ToDate)
		AND IsTest = 0
		AND (@SelectedSiteNames = 'All' OR (MessageID IN (SELECT MessageID FROM @tblTicketBySites)))
	)
	
	INSERT INTO @messageResult (MessageId, Subject, Content, Status, EventDate, PublishedDate, TotalRecords)		
	SELECT tmp.MessageId, tmp.Subject, tmp.Content, tmp.Status, tmp.EventDate, tmp.PublishedDate,
		(SELECT MAX(RowNumber) FROM tempMessage) AS TotalRecords
	FROM tempMessage tmp		
	WHERE tmp.RowNumber BETWEEN @RowStart AND @RowEnd
	ORDER BY tmp.EventDate DESC
	
	-- Select Results
	SELECT MessageId, Subject, Content, Status, EventDate, PublishedDate
	FROM @messageResult
	
	SELECT TicketId, MessageId, LicenseeName AS SiteName, DataFilePath
	FROM dbo.AmendmentTicket WITH(NOLOCK)
	WHERE MessageId IN (SELECT MessageId FROM @messageResult)		
	
	SET @TotalRecords = (SELECT TOP 1 TotalRecords FROM @messageResult)
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_AmendmentNotificationSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_AmendmentNotificationSel    Script Date: 5/24/2018 10:46:21 PM ******/
CREATE PROCEDURE [dbo].[OIC_AmendmentNotificationSel]
	@MessageId	INT
AS
/*
	Created by: Scofield
	Date: 20171017 [#84004]
	DB: DBOIC.bodb_OIC
	
	Revisions:	
		- 20171030@Scofield: #84004 - Implement Deliver notification to licensee backend
		- 20180202@Scofield: #90464 - Add PublishedDate
 */
BEGIN
	SET NOCOUNT ON
		
	SELECT MessageId, SubjectEn, SubjectCh, SubjectCs, ContentEn, ContentCh, ContentCs, Status, EventDate, PublishedDate
	FROM dbo.AmendmentMessage WITH(NOLOCK)
	WHERE MessageID = @MessageId
			
	SELECT TicketId, MessageId, LicenseeName AS SiteName, DataFilePath
	FROM dbo.AmendmentTicket WITH(NOLOCK)
	WHERE MessageID = @MessageId
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_AmendmentNotificationSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OIC_AmendmentNotificationSel_xtest]
	@MessageId	INT
AS
/*
	Created by: Scofield
	Date: 20171017 [#84004]
	DB: DBOIC.bodb_OIC
	
	Revisions:	
		- 20171030@Scofield: #84004 - Implement Deliver notification to licensee backend
		- 20180202@Scofield: #90464 - Add PublishedDate
 */
BEGIN
	SET NOCOUNT ON
		
	SELECT MessageId, SubjectEn, SubjectCh, SubjectCs, ContentEn, ContentCh, ContentCs, Status, EventDate, PublishedDate
	FROM dbo.AmendmentMessage WITH(NOLOCK)
	WHERE MessageID = @MessageId
			
	SELECT TicketId, MessageId, LicenseeName AS SiteName, DataFilePath
	FROM dbo.AmendmentTicket WITH(NOLOCK)
	WHERE MessageID = @MessageId
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_AmendmentNotificationUpd]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_AmendmentNotificationUpd    Script Date: 5/24/2018 10:46:22 PM ******/
CREATE PROCEDURE [dbo].[OIC_AmendmentNotificationUpd] 
	@MessageId			INT,
	@Status				INT,
	@SubjectEn			NVARCHAR(300),
	@SubjectCh			NVARCHAR(300) = '',
	@SubjectCs			NVARCHAR(300) = '',
	@ContentEn			NVARCHAR(MAX) = '',
	@ContentCh			NVARCHAR(MAX) = '',
	@ContentCs			NVARCHAR(MAX) = '',	
		
	@UserId				INT,
	@Language			VARCHAR(10)		= 'E',
	@IP					VARCHAR(50)		= NULL,
	@ErrCode			INT				= 0			OUTPUT,
	@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Scofield
	Date: 20171019
	Task: Upate amendment notification [Redmine: #84004]
	DB: DBOIC.bodb_OIC
	
	Revisions:	
		- 20171030@Scofield: #84004 - Implement Deliver notification to licensee backend
		- 20180202@Scofield: #90464 - Add PublishedDate
	
	Param's Explanation:
		@Status: 0: New, 1: Active, 2: Inactive				
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @startRun		DATETIME,
			@endRun			DATETIME,
			@duration		INT,
			@logSPOldData	NVARCHAR(MAX),
			@logSPData		NVARCHAR(MAX),
			@xml			XML,
			@procName		VARCHAR(200)			
			
	SET @startRun = GETDATE()	
	
	-- get data before update/insert		
	SET @xml = (
				SELECT	Status				AS '@sta',
						SubjectEn			AS '@sen',
						SubjectCh			AS '@sch',
						SubjectCs			AS '@scs',
						ContentEn			AS '@cen',
						ContentCh			AS '@cch',
						ContentCs			AS '@ccs'
				FROM	dbo.AmendmentMessage u WITH(NOLOCK)
				WHERE	MessageId = @MessageId
				FOR XML PATH('r'), TYPE
	)	
	SELECT @logSPOldData = CONVERT(NVARCHAR(MAX),@xml)
					
	BEGIN TRY
		DECLARE @Tmp TABLE (Status INT, PublishedDate DATETIME)
		
		INSERT INTO @Tmp(Status, PublishedDate)
		SELECT TOP 1 Status, PublishedDate
		FROM dbo.AmendmentMessage WITH(NOLOCK) 
		WHERE MessageId = @MessageId
		
		DECLARE @CurrentStatus INT = (SELECT TOP 1 Status FROM @Tmp)
		DECLARE @CurrentPublishedDate DATETIME = (SELECT TOP 1 PublishedDate FROM @Tmp)
		
		IF @CurrentPublishedDate IS NULL AND @CurrentStatus = 0 AND @Status = 1	
		BEGIN
			UPDATE dbo.AmendmentMessage WITH(ROWLOCK, UPDLOCK)
			SET PublishedDate = GETDATE()
			WHERE MessageId = @MessageId
	     END
					
		UPDATE dbo.AmendmentMessage WITH(ROWLOCK, UPDLOCK)
		SET Status = @Status, 
			SubjectEn = @SubjectEn, SubjectCh = @SubjectCh, SubjectCs = @SubjectCs,
			ContentEn = @ContentEn, ContentCh = @ContentCh, ContentCs = @ContentCs,
			UpdatedDate = GETDATE(), UpdatedBy = @UserId
		WHERE MessageId = @MessageId
	END TRY
	BEGIN CATCH			
			SELECT	@Errcode = 100,
					@ErrMsg = dbo.f_Get_MsgNamebyMsgID (40003, @Language)
			RETURN
	END CATCH		
	
	-- Write log	
	SET @xml = (
				SELECT	@Status				AS '@sta',
						@SubjectEn			AS '@sen',
						@SubjectCh			AS '@sch',
						@SubjectCs			AS '@scs',
						@ContentEn			AS '@cen',
						@ContentCh			AS '@cch',
						@ContentCs			AS '@ccs'
				FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData	= CONVERT(NVARCHAR(MAX),@xml)
		,@endRun		= GETDATE()  
		,@duration		= DATEDIFF(millisecond, @startRun, @endRun)   
		,@procName		= OBJECT_NAME(@@procid)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOldData
		,@Duration		= @Duration
	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_AmendmentNotificationUpd_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OIC_AmendmentNotificationUpd_xtest] 
	@MessageId			INT,
	@Status				INT,
	@SubjectEn			NVARCHAR(300),
	@SubjectCh			NVARCHAR(300) = '',
	@SubjectCs			NVARCHAR(300) = '',
	@ContentEn			NVARCHAR(MAX) = '',
	@ContentCh			NVARCHAR(MAX) = '',
	@ContentCs			NVARCHAR(MAX) = '',	
		
	@UserId				INT,
	@Language			VARCHAR(10)		= 'E',
	@IP					VARCHAR(50)		= NULL,
	@ErrCode			INT				= 0			OUTPUT,
	@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Scofield
	Date: 20171019
	Task: Upate amendment notification [Redmine: #84004]
	DB: DBOIC.bodb_OIC
	
	Revisions:	
		- 20171030@Scofield: #84004 - Implement Deliver notification to licensee backend
		- 20180202@Scofield: #90464 - Add PublishedDate
	
	Param's Explanation:
		@Status: 0: New, 1: Active, 2: Inactive				
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @startRun		DATETIME,
			@endRun			DATETIME,
			@duration		INT,
			@logSPOldData	NVARCHAR(MAX),
			@logSPData		NVARCHAR(MAX),
			@xml			XML,
			@procName		VARCHAR(200)			
			
	SET @startRun = GETDATE()	
	
	-- get data before update/insert		
	SET @xml = (
				SELECT	Status				AS '@sta',
						SubjectEn			AS '@sen',
						SubjectCh			AS '@sch',
						SubjectCs			AS '@scs',
						ContentEn			AS '@cen',
						ContentCh			AS '@cch',
						ContentCs			AS '@ccs'
				FROM	dbo.AmendmentMessage u WITH(NOLOCK)
				WHERE	MessageId = @MessageId
				FOR XML PATH('r'), TYPE
	)	
	SELECT @logSPOldData = CONVERT(NVARCHAR(MAX),@xml)
					
	BEGIN TRY
		DECLARE @Tmp TABLE (Status INT, PublishedDate DATETIME)
		
		INSERT INTO @Tmp(Status, PublishedDate)
		SELECT TOP 1 Status, PublishedDate
		FROM dbo.AmendmentMessage WITH(NOLOCK) 
		WHERE MessageId = @MessageId
		
		DECLARE @CurrentStatus INT = (SELECT TOP 1 Status FROM @Tmp)
		DECLARE @CurrentPublishedDate DATETIME = (SELECT TOP 1 PublishedDate FROM @Tmp)
		
		IF @CurrentPublishedDate IS NULL AND @CurrentStatus = 0 AND @Status = 1	
		BEGIN
			UPDATE dbo.AmendmentMessage WITH(ROWLOCK, UPDLOCK)
			SET PublishedDate = GETDATE()
			WHERE MessageId = @MessageId
	     END
					
		UPDATE dbo.AmendmentMessage WITH(ROWLOCK, UPDLOCK)
		SET Status = @Status, 
			SubjectEn = @SubjectEn, SubjectCh = @SubjectCh, SubjectCs = @SubjectCs,
			ContentEn = @ContentEn, ContentCh = @ContentCh, ContentCs = @ContentCs,
			UpdatedDate = GETDATE(), UpdatedBy = @UserId
		WHERE MessageId = @MessageId
	END TRY
	BEGIN CATCH			
			SELECT	@Errcode = 100,
					@ErrMsg = dbo.f_Get_MsgNamebyMsgID (40003, @Language)
			RETURN
	END CATCH		
	
	-- Write log	
	SET @xml = (
				SELECT	@Status				AS '@sta',
						@SubjectEn			AS '@sen',
						@SubjectCh			AS '@sch',
						@SubjectCs			AS '@scs',
						@ContentEn			AS '@cen',
						@ContentCh			AS '@cch',
						@ContentCs			AS '@ccs'
				FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData	= CONVERT(NVARCHAR(MAX),@xml)
		,@endRun		= GETDATE()  
		,@duration		= DATEDIFF(millisecond, @startRun, @endRun)   
		,@procName		= OBJECT_NAME(@@procid)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOldData
		,@Duration		= @Duration
	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_API_AmendmentMessageIns]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_API_AmendmentMessageIns    Script Date: 1/18/2018 4:06:45 AM ******/
CREATE PROCEDURE [dbo].[OIC_API_AmendmentMessageIns]
	 @Title			NVARCHAR(300)
	,@ReceivedDate	DATETIME
	,@EventDate		DATETIME -- Match Event Date
	,@Tickets		XML
	,@SiteId		SMALLINT
	,@IsTest		BIT				= 0
	,@IP			VARCHAR(50)		= NULL
	,@ErrCode		INT				= 0			OUTPUT
	,@ErrMsg		VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: bruce.bui
	Date: 20171010
	Task: Insert amendment result [Redmine:#81860]
	DB: DBOIC.bodb_OIC
	
	Revisions:	
		- 20171030@Scofield: #84004 - Implement Deliver notification to licensee backend
		- 20180118@Alex	   : #89670 - Insert Event Date
	Param's Explanation:
		@SiteId: 0 - Special delete
				 -1 - LRF
		@Tickets: xml format
			<root>
				<ticket name="licensee name1" path="file path1"/>
				<ticket name="licensee name2" path="file path2"/>
			</root>
	     status column = 0 -- for new result.
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @startRun DATETIME = GETDATE()
	SELECT @Errcode = 0, @ErrMsg = ''
	
	BEGIN TRY		
		INSERT INTO dbo.AmendmentMessage(SubjectEn, [Status], ReceivedDate, IsTest,EventDate)
		SELECT	@Title, 0, @ReceivedDate, @IsTest,@EventDate
		
		DECLARE @MessageId INT = SCOPE_IDENTITY()
		
		INSERT INTO dbo.AmendmentTicket(LicenseeName, DataFilePath, MessageID)
		SELECT t.c.value('@name','nvarchar(300)'), t.c.value('@path','nvarchar(300)'), @MessageId
		FROM @Tickets.nodes('root/ticket') t(c)
				
	END TRY
	BEGIN CATCH	
		SELECT	@Errcode = 100,
				@ErrMsg = dbo.f_Get_MsgNamebyMsgID (40002, 'E')
		RETURN
	END CATCH

	-- write log
	DECLARE @xml XML = (
		SELECT	CONVERT(NVARCHAR(MAX),@Tickets) AS '@t'
			,@ReceivedDate			AS '@rcd'
			,0						AS '@st'
			,@Title					AS '@tt',
			@EventDate				AS '@evd'
			
		FOR XML PATH('r'), TYPE
	)		
		
	DECLARE @logSPData	NVARCHAR(MAX)	= CONVERT(NVARCHAR(MAX),@xml)
			,@duration	INT				= DATEDIFF(millisecond, @startRun, GETDATE())
			,@procName	VARCHAR(200)	= OBJECT_NAME(@@procid)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @SiteId
		,@SPName		= @procName
		,@Language		= 'E'
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_API_AmendmentMessageIns_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OIC_API_AmendmentMessageIns_xtest]
	 @Title			NVARCHAR(300)
	,@ReceivedDate	DATETIME
	,@EventDate		DATETIME -- Match Event Date
	,@Tickets		XML
	,@SiteId		SMALLINT
	,@IsTest		BIT				= 0
	,@IP			VARCHAR(50)		= NULL
	,@ErrCode		INT				= 0			OUTPUT
	,@ErrMsg		VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: bruce.bui
	Date: 20171010
	Task: Insert amendment result [Redmine:#81860]
	DB: DBOIC.bodb_OIC
	
	Revisions:	
		- 20171030@Scofield: #84004 - Implement Deliver notification to licensee backend
		- 20180118@Alex	   : #89670 - Insert Event Date
	Param's Explanation:
		@SiteId: 0 - Special delete
				 -1 - LRF
		@Tickets: xml format
			<root>
				<ticket name="licensee name1" path="file path1"/>
				<ticket name="licensee name2" path="file path2"/>
			</root>
	     status column = 0 -- for new result.
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @startRun DATETIME = GETDATE()
	SELECT @Errcode = 0, @ErrMsg = ''
	
	BEGIN TRY		
		INSERT INTO dbo.AmendmentMessage(SubjectEn, [Status], ReceivedDate, IsTest,EventDate)
		SELECT	@Title, 0, @ReceivedDate, @IsTest,@EventDate
		
		DECLARE @MessageId INT = SCOPE_IDENTITY()
		
		INSERT INTO dbo.AmendmentTicket(LicenseeName, DataFilePath, MessageID)
		SELECT t.c.value('@name','nvarchar(300)'), t.c.value('@path','nvarchar(300)'), @MessageId
		FROM @Tickets.nodes('root/ticket') t(c)
				
	END TRY
	BEGIN CATCH	
		SELECT	@Errcode = 100,
				@ErrMsg = dbo.f_Get_MsgNamebyMsgID (40002, 'E')
		RETURN
	END CATCH

	-- write log
	DECLARE @xml XML = (
		SELECT	CONVERT(NVARCHAR(MAX),@Tickets) AS '@t'
			,@ReceivedDate			AS '@rcd'
			,0						AS '@st'
			,@Title					AS '@tt',
			@EventDate				AS '@evd'
			
		FOR XML PATH('r'), TYPE
	)		
		
	DECLARE @logSPData	NVARCHAR(MAX)	= CONVERT(NVARCHAR(MAX),@xml)
			,@duration	INT				= DATEDIFF(millisecond, @startRun, GETDATE())
			,@procName	VARCHAR(200)	= OBJECT_NAME(@@procid)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @SiteId
		,@SPName		= @procName
		,@Language		= 'E'
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_API_AmendmentMessageListSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_API_AmendmentMessageListSel    Script Date: 1/25/2018 11:03:45 PM ******/
CREATE PROCEDURE [dbo].[OIC_API_AmendmentMessageListSel]
	@FromDate			DATETIME, -- EventDate
	@ToDate				DATETIME, -- EventDate
	@UserName			NVARCHAR(50),
	@LicenseeName		NVARCHAR(50),
	@IsOnlyUnread		BIT				= 0,	
	@PageSize			INT				= 10,
	@PageIndex			INT				= 0,
	@TotalRecords		INT				= 0	OUTPUT
AS
/*
	Created by: Scofield
	Date: 20171023 [#84004]
	DB: DBOIC.bodb_OIC
	
	Revisions:	
		- 20171030@Scofield: #84004 - Implement Deliver notification to licensee back-end
		- 20170118@Alex    : #89670 - Support to query data by event date
		- 20180123@Scofield: #89901 - Enhance Result Notification function : sorting records

	Param's Explanation:		
 */
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RowStart	INT,
			@RowEnd	INT,
			@ActiveStatus INT = 1,
			@AmendmentMessageType INT = 2
	
	SELECT	@PageIndex   = @PageIndex, 
			@RowStart	 = @PageSize * @PageIndex + 1,
			@RowEnd	     = @RowStart + @PageSize - 1
	SELECT @ToDate = DATEADD(dd, DATEDIFF(dd, 0, @ToDate), 0) + CAST('23:59:59.999' AS Time)
			
	DECLARE @messageResult TABLE (
		MessageId 		INT, 
		SubjectEn 		NVARCHAR(300), 
		SubjectCh 		NVARCHAR(300), 
		SubjectCs 		NVARCHAR(300), 
		ContentEn 		NVARCHAR(MAX), 
		ContentCh 		NVARCHAR(MAX), 
		ContentCs 		NVARCHAR(MAX), 
		EventDate		DateTime,
		IsRead			BIT,
		DataFilePath	VARCHAR(MAX),
		TotalRecords	INT)	
	 
	;WITH tempMessage AS
	(SELECT ROW_NUMBER() OVER(ORDER BY am.EventDate DESC, am.MessageID DESC) AS RowNumber,
		am.MessageID, am.SubjectEn, am.SubjectCh, am.SubjectCs, am.ContentEn, am.ContentCh, am.ContentCs, am.EventDate, at.DataFilePath, 
		ISNULL(mu.IsRead, 0) AS IsRead
	FROM dbo.AmendmentMessage am WITH(NOLOCK)
	INNER JOIN dbo.AmendmentTicket at WITH(NOLOCK) ON am.MessageID = at.MessageID
	LEFT JOIN dbo.ExternalMessageUser mu ON am.MessageID = mu.MessageID AND mu.MessageType = @AmendmentMessageType 
		AND mu.UserName = @UserName AND mu.LicenseeName = @LicenseeName
	WHERE am.Status = @ActiveStatus AND (am.EventDate BETWEEN @FromDate AND @ToDate) AND am.IsTest = 0
		AND at.LicenseeName = @LicenseeName
		AND (@IsOnlyUnread = 0 OR mu.IsRead IS NULL OR mu.IsRead = 0)
	)
		
	INSERT INTO @messageResult(MessageID, SubjectEn, SubjectCh, SubjectCs, ContentEn, ContentCh, ContentCs, EventDate, DataFilePath, IsRead, TotalRecords)
	SELECT tmp.MessageID, tmp.SubjectEn, tmp.SubjectCh, tmp.SubjectCs, tmp.ContentEn, tmp.ContentCh, tmp.ContentCs, tmp.EventDate, tmp.DataFilePath, tmp.IsRead,
		(SELECT MAX(RowNumber) FROM tempMessage) AS TotalRecords
	FROM tempMessage tmp
	WHERE tmp.RowNumber BETWEEN @RowStart AND @RowEnd
	ORDER BY tmp.EventDate DESC
	
	-- Select Results
	SELECT MessageID, SubjectEn, SubjectCh, SubjectCs, ContentEn, ContentCh, ContentCs, EventDate, DataFilePath, IsRead
	FROM @messageResult
	
	SET @TotalRecords = (SELECT TOP 1 TotalRecords FROM @messageResult)
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_API_AmendmentMessageListSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OIC_API_AmendmentMessageListSel_xtest]
	@FromDate			DATETIME, -- EventDate
	@ToDate				DATETIME, -- EventDate
	@UserName			NVARCHAR(50),
	@LicenseeName		NVARCHAR(50),
	@IsOnlyUnread		BIT				= 0,	
	@PageSize			INT				= 10,
	@PageIndex			INT				= 0,
	@TotalRecords		INT				= 0	OUTPUT
AS
/*
	Created by: Scofield
	Date: 20171023 [#84004]
	DB: DBOIC.bodb_OIC
	
	Revisions:	
		- 20171030@Scofield: #84004 - Implement Deliver notification to licensee back-end
		- 20170118@Alex    : #89670 - Support to query data by event date
		- 20180123@Scofield: #89901 - Enhance Result Notification function : sorting records

	Param's Explanation:		
 */
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RowStart	INT,
			@RowEnd	INT,
			@ActiveStatus INT = 1,
			@AmendmentMessageType INT = 2
	
	SELECT	@PageIndex   = @PageIndex, 
			@RowStart	 = @PageSize * @PageIndex + 1,
			@RowEnd	     = @RowStart + @PageSize - 1
	SELECT @ToDate = DATEADD(dd, DATEDIFF(dd, 0, @ToDate), 0) + CAST('23:59:59.999' AS Time)
			
	DECLARE @messageResult TABLE (
		MessageId 		INT, 
		SubjectEn 		NVARCHAR(300), 
		SubjectCh 		NVARCHAR(300), 
		SubjectCs 		NVARCHAR(300), 
		ContentEn 		NVARCHAR(MAX), 
		ContentCh 		NVARCHAR(MAX), 
		ContentCs 		NVARCHAR(MAX), 
		EventDate		DateTime,
		IsRead			BIT,
		DataFilePath	VARCHAR(MAX),
		TotalRecords	INT)	
	 
	;WITH tempMessage AS
	(SELECT ROW_NUMBER() OVER(ORDER BY am.EventDate DESC, am.MessageID DESC) AS RowNumber,
		am.MessageID, am.SubjectEn, am.SubjectCh, am.SubjectCs, am.ContentEn, am.ContentCh, am.ContentCs, am.EventDate, at.DataFilePath, 
		ISNULL(mu.IsRead, 0) AS IsRead
	FROM dbo.AmendmentMessage am WITH(NOLOCK)
	INNER JOIN dbo.AmendmentTicket at WITH(NOLOCK) ON am.MessageID = at.MessageID
	LEFT JOIN dbo.ExternalMessageUser mu ON am.MessageID = mu.MessageID AND mu.MessageType = @AmendmentMessageType 
		AND mu.UserName = @UserName AND mu.LicenseeName = @LicenseeName
	WHERE am.Status = @ActiveStatus AND (am.EventDate BETWEEN @FromDate AND @ToDate) AND am.IsTest = 0
		AND at.LicenseeName = @LicenseeName
		AND (@IsOnlyUnread = 0 OR mu.IsRead IS NULL OR mu.IsRead = 0)
	)
		
	INSERT INTO @messageResult(MessageID, SubjectEn, SubjectCh, SubjectCs, ContentEn, ContentCh, ContentCs, EventDate, DataFilePath, IsRead, TotalRecords)
	SELECT tmp.MessageID, tmp.SubjectEn, tmp.SubjectCh, tmp.SubjectCs, tmp.ContentEn, tmp.ContentCh, tmp.ContentCs, tmp.EventDate, tmp.DataFilePath, tmp.IsRead,
		(SELECT MAX(RowNumber) FROM tempMessage) AS TotalRecords
	FROM tempMessage tmp
	WHERE tmp.RowNumber BETWEEN @RowStart AND @RowEnd
	ORDER BY tmp.EventDate DESC
	
	-- Select Results
	SELECT MessageID, SubjectEn, SubjectCh, SubjectCs, ContentEn, ContentCh, ContentCs, EventDate, DataFilePath, IsRead
	FROM @messageResult
	
	SET @TotalRecords = (SELECT TOP 1 TotalRecords FROM @messageResult)
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_API_ExternalMessageUserIns]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_API_ExternalMessageUserIns    Script Date: 1/17/2018 7:23:58 AM ******/
CREATE PROCEDURE [dbo].[OIC_API_ExternalMessageUserIns]
	@MessageID			INT,
	@MessageType			INT,
	@UserName			NVARCHAR(100),
	@LicenseeName		NVARCHAR(100),
	@IP				VARCHAR(50)	= NULL,
	@ErrCode			INT			= 0			OUTPUT,
	@ErrMsg			VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Scofield
	Date: 20171023 [#84004]
	DB: DBOIC.bodb_OIC
	
	Revisions:	
		- 20171030@Scofield: #84004 - Implement Deliver notification to licensee backend

	Param's Explanation:
 */
BEGIN
	SET NOCOUNT ON
	DECLARE @startRun		DATETIME,
			@endRun		DATETIME,
			@duration		INT,
			@logSPData	NVARCHAR(MAX),
			@xml			XML,
			@procName		VARCHAR(200)	

    SET @startRun = GETDATE()	
	
	BEGIN TRY	
		IF EXISTS (SELECT TOP 1 1 FROM dbo.ExternalMessageUser WITH(NOLOCK) 
					WHERE MessageID = @MessageID AND MessageType = @MessageType AND UserName = @UserName AND LicenseeName = @LicenseeName)
			BEGIN
				UPDATE dbo.ExternalMessageUser 
				SET IsRead = 1, UpdatedDate = GETDATE()
				WHERE MessageID = @MessageID AND MessageType = @MessageType AND UserName = @UserName AND LicenseeName = @LicenseeName			
			END
		ELSE	
			BEGIN
				INSERT INTO dbo.ExternalMessageUser (MessageID, MessageType, UserName, LicenseeName, IsRead, UpdatedDate)
				VALUES (@MessageID, @MessageType, @UserName, @LicenseeName, 1, GETDATE())
			END
	END TRY
	BEGIN CATCH	
		SELECT	@Errcode = 100,
				@ErrMsg = dbo.f_Get_MsgNamebyMsgID (40004, 'E')
		RETURN
	END CATCH
	
	-- write log
	SET @xml = (
			 SELECT	@MessageID			AS '@mid',
					@MessageType		AS '@mty',
					   @UserName		AS '@una',
					   @LicenseeName	AS '@lin'
			 FOR XML PATH('r'), TYPE)		
		
	SELECT @logSPData	= CONVERT(NVARCHAR(MAX),@xml)
		,@endRun		= GETDATE()  
		,@duration	= DATEDIFF(millisecond, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@procid)

	EXEC dbo.OIC_LogRunSpIns
		@UserId		= -1
		,@SPName		= @procName
		,@Language	= 'E'
		,@IP			= @IP
		,@Data		= @logSPData
		,@OldData		= Null
		,@Duration	= @duration
	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_API_ExternalMessageUserIns_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OIC_API_ExternalMessageUserIns_xtest]
	@MessageID			INT,
	@MessageType			INT,
	@UserName			NVARCHAR(100),
	@LicenseeName		NVARCHAR(100),
	@IP				VARCHAR(50)	= NULL,
	@ErrCode			INT			= 0			OUTPUT,
	@ErrMsg			VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Scofield
	Date: 20171023 [#84004]
	DB: DBOIC.bodb_OIC
	
	Revisions:	
		- 20171030@Scofield: #84004 - Implement Deliver notification to licensee backend

	Param's Explanation:
 */
BEGIN
	SET NOCOUNT ON
	DECLARE @startRun		DATETIME,
			@endRun		DATETIME,
			@duration		INT,
			@logSPData	NVARCHAR(MAX),
			@xml			XML,
			@procName		VARCHAR(200)	

    SET @startRun = GETDATE()	
	
	BEGIN TRY	
		IF EXISTS (SELECT TOP 1 1 FROM dbo.ExternalMessageUser WITH(NOLOCK) 
					WHERE MessageID = @MessageID AND MessageType = @MessageType AND UserName = @UserName AND LicenseeName = @LicenseeName)
			BEGIN
				UPDATE dbo.ExternalMessageUser 
				SET IsRead = 1, UpdatedDate = GETDATE()
				WHERE MessageID = @MessageID AND MessageType = @MessageType AND UserName = @UserName AND LicenseeName = @LicenseeName			
			END
		ELSE	
			BEGIN
				INSERT INTO dbo.ExternalMessageUser (MessageID, MessageType, UserName, LicenseeName, IsRead, UpdatedDate)
				VALUES (@MessageID, @MessageType, @UserName, @LicenseeName, 1, GETDATE())
			END
	END TRY
	BEGIN CATCH	
		SELECT	@Errcode = 100,
				@ErrMsg = dbo.f_Get_MsgNamebyMsgID (40004, 'E')
		RETURN
	END CATCH
	
	-- write log
	SET @xml = (
			 SELECT	@MessageID			AS '@mid',
					@MessageType		AS '@mty',
					   @UserName		AS '@una',
					   @LicenseeName	AS '@lin'
			 FOR XML PATH('r'), TYPE)		
		
	SELECT @logSPData	= CONVERT(NVARCHAR(MAX),@xml)
		,@endRun		= GETDATE()  
		,@duration	= DATEDIFF(millisecond, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@procid)

	EXEC dbo.OIC_LogRunSpIns
		@UserId		= -1
		,@SPName		= @procName
		,@Language	= 'E'
		,@IP			= @IP
		,@Data		= @logSPData
		,@OldData		= Null
		,@Duration	= @duration
	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_API_ExternalNotificationListSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_API_ExternalNotificationListSel    Script Date: 1/18/2018 4:06:47 AM ******/
CREATE PROCEDURE [dbo].[OIC_API_ExternalNotificationListSel]
	@MessageTypeId		INT			= 0,
	@FromDate			DATETIME,
	@ToDate				DATETIME, 
	@UserName			NVARCHAR(50),
	@LicenseeName		NVARCHAR(50),
	@IsOnlyUnread		BIT				= 0,	
	@PageSize			INT				= 10,
	@PageIndex			INT				= 0,
	@TotalRecords		INT				= 0	OUTPUT
AS
/*
	Created by: Scofield
	Date: 20171025
	Task: [Redmine:#84004]
	DB: DBOIC.bodb_OIC
	
	Revisions:	
		- 20171030@Scofield: #84004 - Implement Deliver notification to licensee backend

	Param's Explanation:
		@MessageTypeId:	 
			0 :"All"
			40:"Public",
			41:"Special",
			42:"Personal",
			43:"Match delay - New",
			44:"Match delay - Done"
 */
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RowStart	INT,
			@RowEnd	INT,
			@ActiveStatus INT = 2,
			@GeneralMessageType INT = 1
	
	SELECT	@PageIndex   = @PageIndex, 
			@RowStart	 = @PageSize * @PageIndex + 1,
			@RowEnd	     = @RowStart + @PageSize - 1
	SELECT @ToDate = DATEADD(dd, DATEDIFF(dd, 0, @ToDate), 0) + CAST('23:59:59.999' AS Time)
			
	DECLARE @messageResult TABLE (
		MessageId 		INT, 
		MessageTypeId	INT,
		SubjectEn 		NVARCHAR(300), 
		SubjectCh 		NVARCHAR(300), 
		SubjectCs 		NVARCHAR(300), 
		ContentEn 		NVARCHAR(MAX), 
		ContentCh 		NVARCHAR(MAX), 
		ContentCs 		NVARCHAR(MAX), 
		CreateTime		DateTime,
		IsRead			BIT,
		TotalRecords	INT)			
	
	;WITH tempMessage AS
	(SELECT ROW_NUMBER() OVER(ORDER BY m.CreateTime DESC) AS RowNumber,
		m.MessageId, m.SubjectEn, m.SubjectCh, m.SubjectCs, m.ContentEn, m.ContentCh, m.ContentCs, m.MessageTypeId, m.CreateTime, ISNULL(um.IsRead, 0) AS IsRead
	FROM dbo.Message m
	INNER JOIN dbo.LicenseeMessage lm ON m.MessageId = lm.MessageId
	INNER JOIN dbo.Licensee l ON lm.LicenseeId = l.LicenseeId
	LEFT JOIN dbo.ExternalMessageUser um ON um.MessageId = m.MessageId AND um.MessageType = @GeneralMessageType 
		AND um.UserName = @UserName AND um.LicenseeName = @LicenseeName
	WHERE (@MessageTypeId = 0 OR m.MessageTypeId =@MessageTypeId)
		AND m.MessageTypeId IN (40, 41, 42, 43, 44)
		AND m.CreateTime BETWEEN @FromDate AND @ToDate
		AND l.LicenseeName = @LicenseeName
		AND (@IsOnlyUnread = 0 OR um.IsRead IS NULL OR um.IsRead = 0)
	)
	
	INSERT INTO @messageResult(MessageID, MessageTypeId, SubjectEn, SubjectCh, SubjectCs, ContentEn, ContentCh, ContentCs, CreateTime, IsRead, TotalRecords)
	SELECT tmp.MessageID, tmp.MessageTypeId, tmp.SubjectEn, tmp.SubjectCh, tmp.SubjectCs, tmp.ContentEn, tmp.ContentCh, tmp.ContentCs, tmp.CreateTime, tmp.IsRead, 
		(SELECT MAX(RowNumber) FROM tempMessage) AS TotalRecords
	FROM tempMessage tmp
	WHERE tmp.RowNumber BETWEEN @RowStart AND @RowEnd
	ORDER BY tmp.CreateTime DESC
	
	-- Select Results
	SELECT MessageID, MessageTypeId, SubjectEn, SubjectCh, SubjectCs, ContentEn, ContentCh, ContentCs, CreateTime AS "Date", IsRead
	FROM @messageResult
	
	SET @TotalRecords = (SELECT TOP 1 TotalRecords FROM @messageResult)
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_API_ExternalNotificationListSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OIC_API_ExternalNotificationListSel_xtest]
	@MessageTypeId		INT			= 0,
	@FromDate			DATETIME,
	@ToDate				DATETIME, 
	@UserName			NVARCHAR(50),
	@LicenseeName		NVARCHAR(50),
	@IsOnlyUnread		BIT				= 0,	
	@PageSize			INT				= 10,
	@PageIndex			INT				= 0,
	@TotalRecords		INT				= 0	OUTPUT
AS
/*
	Created by: Scofield
	Date: 20171025
	Task: [Redmine:#84004]
	DB: DBOIC.bodb_OIC
	
	Revisions:	
		- 20171030@Scofield: #84004 - Implement Deliver notification to licensee backend

	Param's Explanation:
		@MessageTypeId:	 
			0 :"All"
			40:"Public",
			41:"Special",
			42:"Personal",
			43:"Match delay - New",
			44:"Match delay - Done"
 */
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RowStart	INT,
			@RowEnd	INT,
			@ActiveStatus INT = 2,
			@GeneralMessageType INT = 1
	
	SELECT	@PageIndex   = @PageIndex, 
			@RowStart	 = @PageSize * @PageIndex + 1,
			@RowEnd	     = @RowStart + @PageSize - 1
	SELECT @ToDate = DATEADD(dd, DATEDIFF(dd, 0, @ToDate), 0) + CAST('23:59:59.999' AS Time)
			
	DECLARE @messageResult TABLE (
		MessageId 		INT, 
		MessageTypeId	INT,
		SubjectEn 		NVARCHAR(300), 
		SubjectCh 		NVARCHAR(300), 
		SubjectCs 		NVARCHAR(300), 
		ContentEn 		NVARCHAR(MAX), 
		ContentCh 		NVARCHAR(MAX), 
		ContentCs 		NVARCHAR(MAX), 
		CreateTime		DateTime,
		IsRead			BIT,
		TotalRecords	INT)			
	
	;WITH tempMessage AS
	(SELECT ROW_NUMBER() OVER(ORDER BY m.CreateTime DESC) AS RowNumber,
		m.MessageId, m.SubjectEn, m.SubjectCh, m.SubjectCs, m.ContentEn, m.ContentCh, m.ContentCs, m.MessageTypeId, m.CreateTime, ISNULL(um.IsRead, 0) AS IsRead
	FROM dbo.Message m
	INNER JOIN dbo.LicenseeMessage lm ON m.MessageId = lm.MessageId
	INNER JOIN dbo.Licensee l ON lm.LicenseeId = l.LicenseeId
	LEFT JOIN dbo.ExternalMessageUser um ON um.MessageId = m.MessageId AND um.MessageType = @GeneralMessageType 
		AND um.UserName = @UserName AND um.LicenseeName = @LicenseeName
	WHERE (@MessageTypeId = 0 OR m.MessageTypeId =@MessageTypeId)
		AND m.MessageTypeId IN (40, 41, 42, 43, 44)
		AND m.CreateTime BETWEEN @FromDate AND @ToDate
		AND l.LicenseeName = @LicenseeName
		AND (@IsOnlyUnread = 0 OR um.IsRead IS NULL OR um.IsRead = 0)
	)
	
	INSERT INTO @messageResult(MessageID, MessageTypeId, SubjectEn, SubjectCh, SubjectCs, ContentEn, ContentCh, ContentCs, CreateTime, IsRead, TotalRecords)
	SELECT tmp.MessageID, tmp.MessageTypeId, tmp.SubjectEn, tmp.SubjectCh, tmp.SubjectCs, tmp.ContentEn, tmp.ContentCh, tmp.ContentCs, tmp.CreateTime, tmp.IsRead, 
		(SELECT MAX(RowNumber) FROM tempMessage) AS TotalRecords
	FROM tempMessage tmp
	WHERE tmp.RowNumber BETWEEN @RowStart AND @RowEnd
	ORDER BY tmp.CreateTime DESC
	
	-- Select Results
	SELECT MessageID, MessageTypeId, SubjectEn, SubjectCh, SubjectCs, ContentEn, ContentCh, ContentCs, CreateTime AS "Date", IsRead
	FROM @messageResult
	
	SET @TotalRecords = (SELECT TOP 1 TotalRecords FROM @messageResult)
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_CategoryMailingDel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_CategoryMailingDel    Script Date: 11/21/2016 10:54:13 PM ******/
/****** Object:  Stored Procedure dbo.OIC_CategoryMailingDel    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_CategoryMailingDel]
	@CategoryId				TINYINT
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: delete TOL [Redmine:#44253]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160818@Percy: Add new param local: @CategoryNameCN -- Chinese [RedmineID: #62642]
 */
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
	
	DECLARE @CategoryName VARCHAR(100), @CategoryNameCN NVARCHAR(100)

	SET @startRun = GETDATE()		
	
	SELECT	@CategoryName = CategoryName, @CategoryNameCN = CategoryNameCN
	FROM	dbo.Category WITH(NOLOCK)
	WHERE	CategoryId = @CategoryId
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.LicenseeCategoryAssigned WITH(NOLOCK) WHERE CategoryId = @CategoryId)
	BEGIN
		SELECT @ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID] (30014, @Language) -- Unable to delete the category because one or many assigned client(s) exist(s)
		RETURN
	END
	
	BEGIN TRY
		DELETE
		FROM	dbo.Category WITH(ROWLOCK, UPDLOCK)
		WHERE	CategoryId = @CategoryId	
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID] (30015, @Language) -- Fail to delete category. Please try again.
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	@CategoryId		AS '@ci'
				,@CategoryName	AS '@cn'
				,@CategoryNameCN AS '@cncn'
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

		EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= NULL
		,@OldData		= @logSPData
		,@Duration		= @Duration
	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_CategoryMailingDel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_CategoryMailingDel_xtest    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_CategoryMailingDel_xtest]
	@CategoryId				TINYINT
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: delete TOL [Redmine:#44253]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160818@Percy: Add new param local: @CategoryNameCN -- Chinese [RedmineID: #62642]
 */
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
	
	DECLARE @CategoryName VARCHAR(100), @CategoryNameCN NVARCHAR(100)

	SET @startRun = GETDATE()		
	
	SELECT	@CategoryName = CategoryName, @CategoryNameCN = CategoryNameCN
	FROM	dbo.Category WITH(NOLOCK)
	WHERE	CategoryId = @CategoryId
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.LicenseeCategoryAssigned WITH(NOLOCK) WHERE CategoryId = @CategoryId)
	BEGIN
		SELECT @ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID] (30014, @Language) -- Unable to delete the category because one or many assigned client(s) exist(s)
		RETURN
	END
	
	BEGIN TRY
		DELETE
		FROM	dbo.Category WITH(ROWLOCK, UPDLOCK)
		WHERE	CategoryId = @CategoryId	
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID] (30015, @Language) -- Fail to delete category. Please try again.
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	@CategoryId		AS '@ci'
				,@CategoryName	AS '@cn'
				,@CategoryNameCN AS '@cncn'
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= NULL
		,@OldData		= @logSPData
		,@Duration		= @Duration
	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_CategoryMailingIns]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_CategoryMailingIns    Script Date: 11/21/2016 10:54:14 PM ******/
/****** Object:  Stored Procedure dbo.OIC_CategoryMailingIns    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_CategoryMailingIns] 
	@CategoryName			VARCHAR(100)
	,@CategoryNameCN		NVARCHAR(100)	= NULL
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: insert new category [Redmine:#44253]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160818@Percy: Add new param: @CategoryNameCN -- Chinese [RedmineID: #62642]
		
 */
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)


	DECLARE @CategoryId TINYINT

	SET @startRun = GETDATE()		
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.Category WITH(NOLOCK) WHERE CategoryName = @CategoryName)
	BEGIN
		SELECT @ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30011, @Language) -- The category name is already used. Please try another name.
		RETURN
	END

	IF EXISTS (SELECT TOP 1 1 FROM dbo.Category WITH(NOLOCK) WHERE CategoryNameCN = @CategoryNameCN)
	BEGIN
		SELECT @ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30028, @Language) -- The Category (Simplified Chinese) is already used. Please try another name.
		RETURN
	END
	
	BEGIN TRY
		INSERT INTO dbo.Category (CategoryName, CategoryNameCN) VALUES (@CategoryName, @CategoryNameCN)
	
		SET @CategoryId = SCOPE_IDENTITY()
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 110
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30012, @Language) -- Fail to create category. Please try again.
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	@CategoryId		AS '@ci'
				,@CategoryName	AS '@cn'
				,@CategoryNameCN AS '@cncn'
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

		EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_CategoryMailingIns_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_CategoryMailingIns_xtest    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_CategoryMailingIns_xtest] 
	@CategoryName			VARCHAR(100)
	,@CategoryNameCN		NVARCHAR(100)	= NULL
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: insert new category [Redmine:#44253]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160818@Percy: Add new param: @CategoryNameCN -- Chinese [RedmineID: #62642]
		
 */
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)


	DECLARE @CategoryId TINYINT

	SET @startRun = GETDATE()		
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.Category WITH(NOLOCK) WHERE CategoryName = @CategoryName)
	BEGIN
		SELECT @ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30011, @Language) -- The category name is already used. Please try another name.
		RETURN
	END

	IF EXISTS (SELECT TOP 1 1 FROM dbo.Category WITH(NOLOCK) WHERE CategoryNameCN = @CategoryNameCN)
	BEGIN
		SELECT @ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30028, @Language) -- The Category (Simplified Chinese) is already used. Please try another name.
		RETURN
	END
	
	BEGIN TRY
		INSERT INTO dbo.Category (CategoryName, CategoryNameCN) VALUES (@CategoryName, @CategoryNameCN)
	
		SET @CategoryId = SCOPE_IDENTITY()
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 110
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30012, @Language) -- Fail to create category. Please try again.
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	@CategoryId		AS '@ci'
				,@CategoryName	AS '@cn'
				,@CategoryNameCN AS '@cncn'
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_CategoryMailingSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_CategoryMailingSel    Script Date: 8/22/2016 10:05:34 PM ******/
/****** Object:  Stored Procedure dbo.OIC_CategoryMailingSel    Script Date: 8/18/2016 2:57:03 PM ******/

CREATE PROCEDURE [dbo].[OIC_CategoryMailingSel]
	@LicenseeId	INT = 0 
	,@SelectedLicensee VARCHAR(1000) = ''
AS
/*
	Created by: Kathy
	Date: 2015-02-04
	Task: Category mailing List [Redmine:#29607]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160818@Percy: Return new column: CategoryNameCN -- Chinese [RedmineID: #62642]
	
	Param's Explanation:
	* @SelectedLicensee: '' - All Licensee
*/
BEGIN
	SET NOCOUNT ON
	
	IF @LicenseeId = 0 AND @SelectedLicensee = ''
	BEGIN
		SELECT	@LicenseeId AS LicenseeId
				,c.CategoryId
				,c.CategoryName
				,c.CategoryNameCN
		FROM	dbo.Category c WITH(NOLOCK)
		
		RETURN
	
	END
	IF @LicenseeId <> 0
	BEGIN
		SELECT	@LicenseeId AS LicenseeId
				,c.CategoryId
				,c.CategoryName
				,c.CategoryNameCN
		FROM	dbo.Category c WITH(NOLOCK)
			INNER JOIN dbo.LicenseeCategoryAssigned l 
				ON	l.CategoryId = c.CategoryId
					AND l.LicenseeId = @LicenseeId
		RETURN
	END
	IF @SelectedLicensee <> ''
	BEGIN
		SELECT	l.LicenseeId
				,c.CategoryId
				,c.CategoryName
				,c.CategoryNameCN
		FROM	dbo.Category c WITH(NOLOCK)
			INNER JOIN dbo.LicenseeCategoryAssigned l 
				ON	l.CategoryId = c.CategoryId
		WHERE l.LicenseeId IN (SELECT val FROM dbo.strSplit(@SelectedLicensee,','))
		
		RETURN
	END
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_CategoryMailingSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_CategoryMailingSel_xtest    Script Date: 8/18/2016 2:57:03 PM ******/

CREATE PROCEDURE [dbo].[OIC_CategoryMailingSel_xtest]
	@LicenseeId	INT = 0 
	,@SelectedLicensee VARCHAR(1000) = ''
AS
/*
	Created by: Kathy
	Date: 2015-02-04
	Task: Category mailing List [Redmine:#29607]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160818@Percy: Return new column: CategoryNameCN -- Chinese [RedmineID: #62642]
	
	Param's Explanation:
	* @SelectedLicensee: '' - All Licensee
*/
BEGIN
	SET NOCOUNT ON
	
	IF @LicenseeId = 0 AND @SelectedLicensee = ''
	BEGIN
		SELECT	@LicenseeId AS LicenseeId
				,c.CategoryId
				,c.CategoryName
				,c.CategoryNameCN
		FROM	dbo.Category c WITH(NOLOCK)
		
		RETURN
	
	END
	IF @LicenseeId <> 0
	BEGIN
		SELECT	@LicenseeId AS LicenseeId
				,c.CategoryId
				,c.CategoryName
				,c.CategoryNameCN
		FROM	dbo.Category c WITH(NOLOCK)
			INNER JOIN dbo.LicenseeCategoryAssigned l 
				ON	l.CategoryId = c.CategoryId
					AND l.LicenseeId = @LicenseeId
		RETURN
	END
	IF @SelectedLicensee <> ''
	BEGIN
		SELECT	l.LicenseeId
				,c.CategoryId
				,c.CategoryName
				,c.CategoryNameCN
		FROM	dbo.Category c WITH(NOLOCK)
			INNER JOIN dbo.LicenseeCategoryAssigned l 
				ON	l.CategoryId = c.CategoryId
		WHERE l.LicenseeId IN (SELECT val FROM dbo.strSplit(@SelectedLicensee,','))
		
		RETURN
	END
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_CategoryMailingUpd]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_CategoryMailingUpd    Script Date: 11/21/2016 10:54:15 PM ******/
/****** Object:  Stored Procedure dbo.OIC_CategoryMailingUpd    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_CategoryMailingUpd] 
	@CategoryId				TINYINT
	,@CategoryName			VARCHAR(100)
	,@CategoryNameCN		NVARCHAR(100)	= NULL
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: update category [Redmine:#44253]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160818@Percy: Add new param: @CategoryNameCN -- Chinese [RedmineID: #62642]
		
 */
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPOlddata	NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)

	SET @startRun = GETDATE()
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.Category WITH(NOLOCK) WHERE CategoryName = @CategoryName AND CategoryId <> @CategoryId)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30011,@Language) -- The category name is already used. Please try another name.
		RETURN
	END
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.Category WITH(NOLOCK) WHERE CategoryNameCN = @CategoryNameCN AND CategoryId <> @CategoryId)
	BEGIN
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30028,@Language) -- The Category (Simplified Chinese) is already used. Please try another name.
		RETURN
	END	
	
	-- get old data
	SET @xml = (
		SELECT	CategoryId		AS '@ci'
				,CategoryName	AS '@cn'
				,CategoryNameCN	AS '@cncn'
		FROM	dbo.Category WITH(NOLOCK)
		WHERE	CategoryId = @CategoryId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPOlddata = CONVERT(NVARCHAR(MAX), @xml)
	
	BEGIN TRY
		UPDATE	dbo.Category WITH(ROWLOCK, UPDLOCK)
			SET	CategoryName = @CategoryName, CategoryNameCN = @CategoryNameCN
		WHERE	CategoryId = @CategoryId	
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30013,@Language) -- Fail to edit category. Please try again.	
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	CategoryId		AS '@ci'
				,CategoryName	AS '@cn'
				,CategoryNameCN	AS '@cncn'
		FROM	dbo.Category WITH(NOLOCK)
		WHERE	CategoryId = @CategoryId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

		EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOlddata
		,@Duration		= @Duration
	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_CategoryMailingUpd_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_CategoryMailingUpd_xtest    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_CategoryMailingUpd_xtest] 
	@CategoryId				TINYINT
	,@CategoryName			VARCHAR(100)
	,@CategoryNameCN		NVARCHAR(100)	= NULL
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: update category [Redmine:#44253]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160818@Percy: Add new param: @CategoryNameCN -- Chinese [RedmineID: #62642]
		
 */
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPOlddata	NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)

	SET @startRun = GETDATE()
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.Category WITH(NOLOCK) WHERE CategoryName = @CategoryName AND CategoryId <> @CategoryId)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30011,@Language) -- The category name is already used. Please try another name.
		RETURN
	END
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.Category WITH(NOLOCK) WHERE CategoryNameCN = @CategoryNameCN AND CategoryId <> @CategoryId)
	BEGIN
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30028,@Language) -- The Category (Simplified Chinese) is already used. Please try another name.
		RETURN
	END	
	
	-- get old data
	SET @xml = (
		SELECT	CategoryId		AS '@ci'
				,CategoryName	AS '@cn'
				,CategoryNameCN	AS '@cncn'
		FROM	dbo.Category WITH(NOLOCK)
		WHERE	CategoryId = @CategoryId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPOlddata = CONVERT(NVARCHAR(MAX), @xml)
	
	BEGIN TRY
		UPDATE	dbo.Category WITH(ROWLOCK, UPDLOCK)
			SET	CategoryName = @CategoryName, CategoryNameCN = @CategoryNameCN
		WHERE	CategoryId = @CategoryId	
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30013,@Language) -- Fail to edit category. Please try again.	
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	CategoryId		AS '@ci'
				,CategoryName	AS '@cn'
				,CategoryNameCN	AS '@cncn'
		FROM	dbo.Category WITH(NOLOCK)
		WHERE	CategoryId = @CategoryId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOlddata
		,@Duration		= @Duration
	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_DBA_UserLicenseeIns]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_DBA_UserLicenseeIns    Script Date: 26/08/2015 12:33:24 PM ******/
CREATE PROCEDURE [dbo].[OIC_DBA_UserLicenseeIns] @userid INT
	,@displayname NVARCHAR(50)
	,@positionId TINYINT = 1 -- admin
	,@licenseetype VARCHAR(50) = '1,2,3,4,5'
AS
BEGIN
	set NOCOUNT ON
	declare @tblLicenseeType table (LicenseeTypeId TINYINT)
	
	IF NOT EXISTS (
			SELECT TOP 1 1
			FROM Position
			WHERE PositionId = @positionId
			) 
		RETURN
		
	Insert into @tblLicenseeType(LicenseeTypeId)
	SELECT LicenseeTypeId
	from dbo.LicenseeType with(NOLOCK)
	WHERE LicenseeTypeId IN (Select val from dbo.strSplit(@LicenseeType, ','))
	
	IF EXISTS (
			SELECT TOP 1 1
			FROM UserInfo WITH (NOLOCK)
			WHERE UserId = @userid
			) 
	BEGIN
		UPDATE dbo.UserInfo WITH(ROWLOCK, UPDLOCK)
		SET PositionId = @PositionId
		WHERE UserId = @UserId
	END
	ELSE
	BEGIN
		INSERT INTO UserInfo (
			UserId
			,DisplayName
			,PositionId
			)
		VALUES (
			@userid
			,@displayname
			,@positionid
			)
	END
	
	MERGE UserLicenseeType ul
	USING (SELECT * FROM @tblLicenseeType) AS t
		ON t.LicenseeTypeId = ul.LicenseeTypeId
		AND ul.UserId = @UserId
	WHEN NOT MATCHED BY TARGET THEN INSERT(LicenseeTypeId, userId) VALUES(t.LicenseeTypeId, @userId)
	WHEN NOT MATCHED BY SOURCE AND ul.userid = @userid THEN DELETE;
	

END
GO
/****** Object:  StoredProcedure [dbo].[OIC_EmailNotificationIns]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_EmailNotificationIns    Script Date: 3/13/2017 11:46:29 PM ******/
/****** Object:  Stored Procedure dbo.OIC_EmailNotificationIns    Script Date: 3/2/2017 10:06:15 AM ******/

CREATE PROCEDURE [dbo].[OIC_EmailNotificationIns] 
	@CategoryId				TINYINT
	,@SelectedLicensee		VARCHAR(MAX)	= 'All'
	,@SubjectEn				NVARCHAR(300)
	,@ContentEn				NVARCHAR(MAX)
	,@ContentCh				NVARCHAR(MAX)	= ''
	,@ContentCs				NVARCHAR(MAX)	= ''
	,@MailCCList			XML				= NULL
	
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150825
	Task: Insert email notification [Redmine:#40305]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160229@Percy: Change write log when editing email cc list [Redmine: #52857]
		- 20170302@Percy: Expand length of Content [RedmineID: #70322]
	
	Param's Explanation:
		@MailCCList format:
			<root>
				<row lid="licenseeID" em="cc mail list" @rt="2"/>
			</root>
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @startRun		DATETIME
			,@endRun		DATETIME
			,@duration		INT
			,@logSPData		NVARCHAR(MAX)
			,@xml			XML
			,@procName		VARCHAR(200)
			,@MessageId		INT
			,@IsTesting		BIT = 0	
			,@log_recipient	XML
			
	DECLARE @tblLicensee TABLE (LicenseeId INT PRIMARY KEY, LicenseeTypeId TINYINT)
	
	SET @startRun = GETDATE()
	
	INSERT INTO @tblLicensee (LicenseeId, LicenseeTypeId)
	SELECT	LicenseeId, LicenseeTypeId
	FROM	dbo.f_LicenseeBelongToUser(@UserId)
	WHERE	LicenseeId IN (SELECT LicenseeId FROM dbo.LicenseeCategoryAssigned WITH(NOLOCK) WHERE CategoryId = @CategoryId)
			AND (@SelectedLicensee = 'All' OR LicenseeId IN (SELECT val FROM dbo.strSplit(@SelectedLicensee,',')))
			
	IF EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE DisplayName LIKE 'starix%' AND UserId = @UserId)
		SET @IsTesting = 1
					
	BEGIN TRY
		INSERT INTO dbo.Message 
		(
				ContentEn
				,ContentCh
				,ContentCs
				,MessageTypeId
				,Creator
				,CreateTime
				,SubjectEn
			
		)
		SELECT	@ContentEn
				,@ContentCh
				,@ContentCs
				,60 -- email
				,@UserId
				,GETDATE()
				,@SubjectEn
		
		SET @MessageId = SCOPE_IDENTITY()
		
		INSERT INTO dbo.LicenseeMessage (LicenseeId, MessageId)
		SELECT	LicenseeId, @MessageId
		FROM	@tblLicensee
		
		IF @IsTesting = 0 -- just insert msg into MessageTarget for real user
		BEGIN
			INSERT INTO dbo.MessageTarget (MessageId, LicenseeTypeId, PositionId)
			SELECT	@MessageId, LicenseeTypeId, 0
			FROM	@tblLicensee
			GROUP BY LicenseeTypeId
		END
	END TRY
	BEGIN CATCH			
			DELETE FROM dbo.LicenseeMessage WITH(ROWLOCK, UPDLOCK)
			WHERE MessageId = @MessageId
			
			DELETE FROM dbo.Message WITH(ROWLOCK, UPDLOCK)
			WHERE MessageId = @MessageId
			
			SELECT	@Errcode = 100
					,@ErrMsg = dbo.f_Get_MsgNamebyMsgID (40000, @Language)
			RETURN
	END CATCH
	
	-- Log Recipient list
	
	SET @SelectedLicensee = ''
	SELECT @SelectedLicensee = @SelectedLicensee +  CAST(LicenseeId AS VARCHAR(10)) + ','
	FROM	@tblLicensee
	
	SET @log_recipient = (
		SELECT	LicenseeId		AS '@lid'
				,Recipient		AS '@re'
				,Recipientname	AS '@rn'
				,email			AS '@em'
				,IsContact		AS '@ic'
				,RecipientType	AS '@rt'
		FROM	dbo.f_RecipientList (@SelectedLicensee, @CategoryId, @UserId)
		WHERE RecipientType <> 2 -- remove type AddToCC
		FOR XML PATH ('row'),TYPE
	)
	-- write log
	SET @xml = (
		SELECT	@CategoryId			AS '@ci'
				,@SelectedLicensee	AS '@lt'
				,@log_recipient
				,CONVERT(XML, REPLACE(REPLACE(CONVERT(NVARCHAR(MAX), @MailCCList), '<root>', ''), '</root>', ''))
		FOR XML PATH('r'), TYPE
		)		
				
	SELECT	@logSPData		= CONVERT(NVARCHAR(MAX), @xml)
			,@endRun		= GETDATE()  
			,@duration		= DATEDIFF(MILLISECOND, @startRun, @endRun)   
			,@procName		= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_EmailNotificationIns_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_EmailNotificationIns_xtest    Script Date: 3/2/2017 10:06:15 AM ******/

CREATE PROCEDURE [dbo].[OIC_EmailNotificationIns_xtest] 
	@CategoryId				TINYINT
	,@SelectedLicensee		VARCHAR(MAX)	= 'All'
	,@SubjectEn				NVARCHAR(300)
	,@ContentEn				NVARCHAR(MAX)
	,@ContentCh				NVARCHAR(MAX)	= ''
	,@ContentCs				NVARCHAR(MAX)	= ''
	,@MailCCList			XML				= NULL
	
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150825
	Task: Insert email notification [Redmine:#40305]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160229@Percy: Change write log when editing email cc list [Redmine: #52857]
		- 20170302@Percy: Expand length of Content [RedmineID: #70322]
	
	Param's Explanation:
		@MailCCList format:
			<root>
				<row lid="licenseeID" em="cc mail list" @rt="2"/>
			</root>
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @startRun		DATETIME
			,@endRun		DATETIME
			,@duration		INT
			,@logSPData		NVARCHAR(MAX)
			,@xml			XML
			,@procName		VARCHAR(200)
			,@MessageId		INT
			,@IsTesting		BIT = 0	
			,@log_recipient	XML
			
	DECLARE @tblLicensee TABLE (LicenseeId INT PRIMARY KEY, LicenseeTypeId TINYINT)
	
	SET @startRun = GETDATE()
	
	INSERT INTO @tblLicensee (LicenseeId, LicenseeTypeId)
	SELECT	LicenseeId, LicenseeTypeId
	FROM	dbo.f_LicenseeBelongToUser(@UserId)
	WHERE	LicenseeId IN (SELECT LicenseeId FROM dbo.LicenseeCategoryAssigned WITH(NOLOCK) WHERE CategoryId = @CategoryId)
			AND (@SelectedLicensee = 'All' OR LicenseeId IN (SELECT val FROM dbo.strSplit(@SelectedLicensee,',')))
			
	IF EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE DisplayName LIKE 'starix%' AND UserId = @UserId)
		SET @IsTesting = 1
					
	BEGIN TRY
		INSERT INTO dbo.Message 
		(
				ContentEn
				,ContentCh
				,ContentCs
				,MessageTypeId
				,Creator
				,CreateTime
				,SubjectEn
			
		)
		SELECT	@ContentEn
				,@ContentCh
				,@ContentCs
				,60 -- email
				,@UserId
				,GETDATE()
				,@SubjectEn
		
		SET @MessageId = SCOPE_IDENTITY()
		
		INSERT INTO dbo.LicenseeMessage (LicenseeId, MessageId)
		SELECT	LicenseeId, @MessageId
		FROM	@tblLicensee
		
		IF @IsTesting = 0 -- just insert msg into MessageTarget for real user
		BEGIN
			INSERT INTO dbo.MessageTarget (MessageId, LicenseeTypeId, PositionId)
			SELECT	@MessageId, LicenseeTypeId, 0
			FROM	@tblLicensee
			GROUP BY LicenseeTypeId
		END
	END TRY
	BEGIN CATCH			
			DELETE FROM dbo.LicenseeMessage WITH(ROWLOCK, UPDLOCK)
			WHERE MessageId = @MessageId
			
			DELETE FROM dbo.Message WITH(ROWLOCK, UPDLOCK)
			WHERE MessageId = @MessageId
			
			SELECT	@Errcode = 100
					,@ErrMsg = dbo.f_Get_MsgNamebyMsgID (40000, @Language)
			RETURN
	END CATCH
	
	-- Log Recipient list
	
	SET @SelectedLicensee = ''
	SELECT @SelectedLicensee = @SelectedLicensee +  CAST(LicenseeId AS VARCHAR(10)) + ','
	FROM	@tblLicensee
	
	SET @log_recipient = (
		SELECT	LicenseeId		AS '@lid'
				,Recipient		AS '@re'
				,Recipientname	AS '@rn'
				,email			AS '@em'
				,IsContact		AS '@ic'
				,RecipientType	AS '@rt'
		FROM	dbo.f_RecipientList (@SelectedLicensee, @CategoryId, @UserId)
		WHERE RecipientType <> 2 -- remove type AddToCC
		FOR XML PATH ('row'),TYPE
	)
	-- write log
	SET @xml = (
		SELECT	@CategoryId			AS '@ci'
				,@SelectedLicensee	AS '@lt'
				,@log_recipient
				,CONVERT(XML, REPLACE(REPLACE(CONVERT(NVARCHAR(MAX), @MailCCList), '<root>', ''), '</root>', ''))
		FOR XML PATH('r'), TYPE
		)		
				
	SELECT	@logSPData		= CONVERT(NVARCHAR(MAX), @xml)
			,@endRun		= GETDATE()  
			,@duration		= DATEDIFF(MILLISECOND, @startRun, @endRun)   
			,@procName		= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_EmailNotificationRecipientSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_EmailNotificationRecipientSel    Script Date: 8/16/2016 4:32:36 AM ******/
/****** Object:  Stored Procedure dbo.OIC_EmailNotificationRecipientSel    Script Date: 8/15/2016 5:12:04 PM ******/
/****** Object:  Stored Procedure dbo.OIC_EmailNotificationRecipientSel    Script Date: 3/3/2016 2:06:52 PM ******/
CREATE PROCEDURE [dbo].[OIC_EmailNotificationRecipientSel] 
	@CategoryId				TINYINT
	,@SelectedLicensee		VARCHAR(MAX)
	,@UserId				INT
	
AS
/*
	Created by: Kathy
	Date: 20150825
	Task: get recipient list [Redmine:#40305]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160226@Percy: Add field AddCC [Redmine: #52857]
	
	Param's Explanation:
	
	*
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @ToList			VARCHAR(MAX) = ''
			,@CcList		VARCHAR(MAX) = ''
			,@AddtoCcList	VARCHAR(MAX) = ''
			,@BccList		VARCHAR(MAX) = ''
			,@RowNumber		INT			 = 0
			,@seq			INT			 = 1
			,@LicenseeId	INT
			,@LicenseeName	NVARCHAR(50)
			
	DECLARE @tblResult TABLE (LicenseeId INT, LicenseeName NVARCHAR(50), ToList VARCHAR(MAX), CcList VARCHAR(MAX), AddtoCcList VARCHAR(MAX), BccList VARCHAR(MAX))
	DECLARE @tblLicensee TABLE (seq INT IDENTITY(1,1), LicenseeId INT, LicenseeName NVARCHAR(50))
	
	INSERT INTO @tblLicensee (LicenseeId, LicenseeName)
	SELECT	f.LicenseeId, f.LicenseeName
	FROM	dbo.f_LicenseeBelongToUser(@userId) f
		INNER JOIN dbo.LicenseeCategoryAssigned lc WITH(NOLOCK)
			ON f.LicenseeId = lc.LicenseeId
	WHERE	lc.CategoryId = @CategoryId
			AND f.LicenseeId IN (SELECT val FROM dbo.strSplit(@SelectedLicensee,','))
	GROUP BY f.LicenseeId, f.LicenseeName
	
	SET @RowNumber = @@rowcount
	
	WHILE @seq <=@RowNumber
	BEGIN
		SELECT	@LicenseeId = LicenseeId
				,@LicenseeName = LicenseeName
		FROM	@tblLicensee
		WHERE	seq = @seq
		
		SELECT	@ToList = CASE WHEN RecipientType = 0 THEN @ToList + ISNULL(Email,'') + ';' ELSE @ToList END
				,@CcList = CASE WHEN RecipientType = 1 THEN @CcList + ISNULL(Email,'') + ';' ELSE @CcList END
				,@AddtoCcList = CASE WHEN RecipientType = 2 THEN @AddtoCcList + ISNULL(Email,'') + ';' ELSE @AddtoCcList END
				,@BccList = CASE WHEN RecipientType = 3 THEN @BccList + ISNULL(Email,'') + ';' ELSE @BccList END
		FROM	dbo.f_RecipientList (CAST(@LicenseeId AS VARCHAR(10)), @CategoryId, @UserId)
		WHERE ISNULL(Email,'') <> ''
	
		INSERT INTO @tblResult (LicenseeId, LicenseeName, ToList, CcList, AddtoCcList, BccList)
		SELECT	@LicenseeId
				,@LicenseeName
				,CASE WHEN ISNULL(@ToList,'') = '' THEN '' ELSE LEFT(@ToList,LEN(@ToList) - 1) END
				,CASE WHEN ISNULL(@CcList,'') = '' THEN '' ELSE LEFT(@CcList,LEN(@CcList) - 1) END
				,CASE WHEN ISNULL(@AddtoCcList,'') = '' THEN '' ELSE LEFT(@AddtoCcList,LEN(@AddtoCcList) - 1) END
				,CASE WHEN ISNULL(@BccList,'') = '' THEN '' ELSE LEFT(@BccList,LEN(@BccList) - 1) END
				
		SELECT	@seq = @seq + 1
				,@ToList =''
				,@CcList =''
				,@AddtoCcList =''
				,@BccList = ''
	END
	
	SELECT	LicenseeId
			,LicenseeName
			,ToList
			,AddtoCcList
			,CcList
			,BccList
	FROM	@tblResult

END
GO
/****** Object:  StoredProcedure [dbo].[OIC_EmailNotificationRecipientSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_EmailNotificationRecipientSel_xtest    Script Date: 8/15/2016 5:12:04 PM ******/
/****** Object:  Stored Procedure dbo.OIC_EmailNotificationRecipientSel_xtest    Script Date: 3/3/2016 2:06:52 PM ******/
CREATE PROCEDURE [dbo].[OIC_EmailNotificationRecipientSel_xtest] 
	@CategoryId				TINYINT
	,@SelectedLicensee		VARCHAR(MAX)
	,@UserId				INT
	
AS
/*
	Created by: Kathy
	Date: 20150825
	Task: get recipient list [Redmine:#40305]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160226@Percy: Add field AddCC [Redmine: #52857]
	
	Param's Explanation:
	
	*
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @ToList			VARCHAR(MAX) = ''
			,@CcList		VARCHAR(MAX) = ''
			,@AddtoCcList	VARCHAR(MAX) = ''
			,@BccList		VARCHAR(MAX) = ''
			,@RowNumber		INT			 = 0
			,@seq			INT			 = 1
			,@LicenseeId	INT
			,@LicenseeName	NVARCHAR(50)
			
	DECLARE @tblResult TABLE (LicenseeId INT, LicenseeName NVARCHAR(50), ToList VARCHAR(MAX), CcList VARCHAR(MAX), AddtoCcList VARCHAR(MAX), BccList VARCHAR(MAX))
	DECLARE @tblLicensee TABLE (seq INT IDENTITY(1,1), LicenseeId INT, LicenseeName NVARCHAR(50))
	
	INSERT INTO @tblLicensee (LicenseeId, LicenseeName)
	SELECT	f.LicenseeId, f.LicenseeName
	FROM	dbo.f_LicenseeBelongToUser(@userId) f
		INNER JOIN dbo.LicenseeCategoryAssigned lc WITH(NOLOCK)
			ON f.LicenseeId = lc.LicenseeId
	WHERE	lc.CategoryId = @CategoryId
			AND f.LicenseeId IN (SELECT val FROM dbo.strSplit(@SelectedLicensee,','))
	GROUP BY f.LicenseeId, f.LicenseeName
	
	SET @RowNumber = @@rowcount
	
	WHILE @seq <=@RowNumber
	BEGIN
		SELECT	@LicenseeId = LicenseeId
				,@LicenseeName = LicenseeName
		FROM	@tblLicensee
		WHERE	seq = @seq
		
		SELECT	@ToList = CASE WHEN RecipientType = 0 THEN @ToList + ISNULL(Email,'') + ';' ELSE @ToList END
				,@CcList = CASE WHEN RecipientType = 1 THEN @CcList + ISNULL(Email,'') + ';' ELSE @CcList END
				,@AddtoCcList = CASE WHEN RecipientType = 2 THEN @AddtoCcList + ISNULL(Email,'') + ';' ELSE @AddtoCcList END
				,@BccList = CASE WHEN RecipientType = 3 THEN @BccList + ISNULL(Email,'') + ';' ELSE @BccList END
		FROM	dbo.f_RecipientList_xtest (CAST(@LicenseeId AS VARCHAR(10)), @CategoryId, @UserId)
		WHERE ISNULL(Email,'') <> ''
	
		INSERT INTO @tblResult (LicenseeId, LicenseeName, ToList, CcList, AddtoCcList, BccList)
		SELECT	@LicenseeId
				,@LicenseeName
				,CASE WHEN ISNULL(@ToList,'') = '' THEN '' ELSE LEFT(@ToList,LEN(@ToList) - 1) END
				,CASE WHEN ISNULL(@CcList,'') = '' THEN '' ELSE LEFT(@CcList,LEN(@CcList) - 1) END
				,CASE WHEN ISNULL(@AddtoCcList,'') = '' THEN '' ELSE LEFT(@AddtoCcList,LEN(@AddtoCcList) - 1) END
				,CASE WHEN ISNULL(@BccList,'') = '' THEN '' ELSE LEFT(@BccList,LEN(@BccList) - 1) END
				
		SELECT	@seq = @seq + 1
				,@ToList =''
				,@CcList =''
				,@AddtoCcList =''
				,@BccList = ''
	END
	
	SELECT	LicenseeId
			,LicenseeName
			,ToList
			,AddtoCcList
			,CcList
			,BccList
	FROM	@tblResult

END
GO
/****** Object:  StoredProcedure [dbo].[OIC_ExternalNotificationIns]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_ExternalNotificationIns    Script Date: 3/13/2017 11:46:30 PM ******/
/****** Object:  Stored Procedure dbo.OIC_ExternalNotificationIns    Script Date: 3/2/2017 10:06:15 AM ******/

CREATE PROCEDURE [dbo].[OIC_ExternalNotificationIns] 
	@MessageTypeId			TINYINT
	,@SelectedLicensee		VARCHAR(MAX)	= 'All'
	,@SubjectEn				NVARCHAR(300)	
	,@SubjectCh				NVARCHAR(300)	= ''
	,@SubjectCs				NVARCHAR(300)	= ''
	,@ContentEn				NVARCHAR(MAX)  
	,@ContentCh				NVARCHAR(MAX)  = ''	
	,@ContentCs				NVARCHAR(MAX)  = ''
	
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150825
	Task: Insert external notification [Redmine:#40305]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20170302@Percy: Expand length of Content [RedmineID: #70322]
	
	Param's Explanation:
		@MessageTypeId: 40: public
						41: special
						42: personal
						43: match delay - new
						44: match delay - done
						
	
	*
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @startRun		DATETIME
			,@endRun		DATETIME
			,@duration		INT
			,@logSPData		NVARCHAR(MAX)
			,@xml			XML
			,@procName		VARCHAR(200)
			,@MessageId		INT
			,@IsTesting		BIT = 0	
			,@log_Licensee	VARCHAR(MAX) = ''
			
	DECLARE @tblLicensee TABLE (LicenseeId INT)
	
	SET @startRun = GETDATE()
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE DisplayName LIKE 'starix%' AND UserId = @UserId)
		SET @IsTesting = 1
	 
	BEGIN TRY
		INSERT INTO dbo.Message 
		(
				ContentEn
				,ContentCh
				,ContentCs
				,MessageTypeId
				,Creator
				,CreateTime
				,SubjectEn
				,SubjectCh
				,SubjectCs
		)
		SELECT	@ContentEn
				,@ContentCh
				,@ContentCs
				,@MessageTypeId
				,@UserId
				,GETDATE()
				,@SubjectEn
				,@SubjectCh
				,@SubjectCs
		
		SET @MessageId = SCOPE_IDENTITY()
		
		IF @MessageTypeId IN (40, 41) -- exlude personal, match delay (42, 43,44)
		BEGIN
			-- send to ALL licensee
			INSERT INTO dbo.LicenseeMessage (LicenseeId, MessageId)
			SELECT	LicenseeId, @MessageId
			FROM	dbo.Licensee WITH(NOLOCK)
			
			-- for log
			SELECT	@log_Licensee = @log_Licensee + CAST(LicenseeId AS VARCHAR(10)) + ','
			FROM	dbo.f_LicenseeBelongToUser(@UserId) 
			
			IF @IsTesting = 0 -- just insert msg into MessageTarget for real user
				INSERT INTO dbo.MessageTarget (MessageId, LicenseeTypeId, PositionId)
				SELECT	@MessageId, LicenseeTypeId, 0
				FROM	dbo.Licensee WITH(NOLOCK)
				GROUP BY LicenseeTypeId
		END
		IF @MessageTypeId IN(42, 43,44) -- Personal,  match delay
		BEGIN
			INSERT INTO dbo.LicenseeMessage (LicenseeId, MessageId)
			SELECT	LicenseeId, @MessageId
			FROM	dbo.f_LicenseeBelongToUser(@UserId)
			WHERE	LicenseeId IN (SELECT val FROM dbo.strSplit(@SelectedLicensee,','))
			
			-- for log
			SELECT @log_Licensee = @SelectedLicensee
			
			IF @IsTesting = 0  -- just insert msg into MessageTarget for real user
				INSERT INTO dbo.MessageTarget (MessageId, LicenseeTypeId, PositionId)
				SELECT	@MessageId, LicenseeTypeId, 0
				FROM	dbo.f_LicenseeBelongToUser(@UserId)
				WHERE	LicenseeId IN (SELECT val FROM dbo.strSplit(@SelectedLicensee,','))
				GROUP BY LicenseeTypeId
		END				
	END TRY
	BEGIN CATCH
			DELETE FROM dbo.MessageTarget WITH(ROWLOCK, UPDLOCK)
			WHERE MessageId = @MessageId
			
			DELETE FROM dbo.LicenseeMessage WITH(ROWLOCK, UPDLOCK)
			WHERE MessageId = @MessageId
			
			DELETE FROM dbo.Message WITH(ROWLOCK, UPDLOCK)
			WHERE MessageId = @MessageId
			
			SELECT	@Errcode = 100
					,@ErrMsg = dbo.f_Get_MsgNamebyMsgID(40000,@Language)
			
			RETURN
	END CATCH
	
	-- write log
		
	SET @xml = (
		SELECT	@MessageTypeId		AS '@mid'
				,@log_Licensee		AS '@lt'			
		FOR XML PATH('r'), TYPE
		)		
				
	SELECT	@logSPData		= CONVERT(NVARCHAR(MAX),@xml)
			,@endRun		= GETDATE()  
			,@duration		= DATEDIFF(millisecond, @startRun, @endRun)   
			,@procName		= OBJECT_NAME(@@procid)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_ExternalNotificationIns_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_ExternalNotificationIns_xtest    Script Date: 3/2/2017 10:06:15 AM ******/

CREATE PROCEDURE [dbo].[OIC_ExternalNotificationIns_xtest] 
	@MessageTypeId			TINYINT
	,@SelectedLicensee		VARCHAR(MAX)	= 'All'
	,@SubjectEn				NVARCHAR(300)	
	,@SubjectCh				NVARCHAR(300)	= ''
	,@SubjectCs				NVARCHAR(300)	= ''
	,@ContentEn				NVARCHAR(MAX)  
	,@ContentCh				NVARCHAR(MAX)  = ''	
	,@ContentCs				NVARCHAR(MAX)  = ''
	
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150825
	Task: Insert external notification [Redmine:#40305]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20170302@Percy: Expand length of Content [RedmineID: #70322]
	
	Param's Explanation:
		@MessageTypeId: 40: public
						41: special
						42: personal
						43: match delay - new
						44: match delay - done
						
	
	*
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @startRun		DATETIME
			,@endRun		DATETIME
			,@duration		INT
			,@logSPData		NVARCHAR(MAX)
			,@xml			XML
			,@procName		VARCHAR(200)
			,@MessageId		INT
			,@IsTesting		BIT = 0	
			,@log_Licensee	VARCHAR(MAX) = ''
			
	DECLARE @tblLicensee TABLE (LicenseeId INT)
	
	SET @startRun = GETDATE()
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE DisplayName LIKE 'starix%' AND UserId = @UserId)
		SET @IsTesting = 1
	 
	BEGIN TRY
		INSERT INTO dbo.Message 
		(
				ContentEn
				,ContentCh
				,ContentCs
				,MessageTypeId
				,Creator
				,CreateTime
				,SubjectEn
				,SubjectCh
				,SubjectCs
		)
		SELECT	@ContentEn
				,@ContentCh
				,@ContentCs
				,@MessageTypeId
				,@UserId
				,GETDATE()
				,@SubjectEn
				,@SubjectCh
				,@SubjectCs
		
		SET @MessageId = SCOPE_IDENTITY()
		
		IF @MessageTypeId IN (40, 41) -- exlude personal, match delay (42, 43,44)
		BEGIN
			-- send to ALL licensee
			INSERT INTO dbo.LicenseeMessage (LicenseeId, MessageId)
			SELECT	LicenseeId, @MessageId
			FROM	dbo.Licensee WITH(NOLOCK)
			
			-- for log
			SELECT	@log_Licensee = @log_Licensee + CAST(LicenseeId AS VARCHAR(10)) + ','
			FROM	dbo.f_LicenseeBelongToUser(@UserId) 
			
			IF @IsTesting = 0 -- just insert msg into MessageTarget for real user
				INSERT INTO dbo.MessageTarget (MessageId, LicenseeTypeId, PositionId)
				SELECT	@MessageId, LicenseeTypeId, 0
				FROM	dbo.Licensee WITH(NOLOCK)
				GROUP BY LicenseeTypeId
		END
		IF @MessageTypeId IN(42, 43,44) -- Personal,  match delay
		BEGIN
			INSERT INTO dbo.LicenseeMessage (LicenseeId, MessageId)
			SELECT	LicenseeId, @MessageId
			FROM	dbo.f_LicenseeBelongToUser(@UserId)
			WHERE	LicenseeId IN (SELECT val FROM dbo.strSplit(@SelectedLicensee,','))
			
			-- for log
			SELECT @log_Licensee = @SelectedLicensee
			
			IF @IsTesting = 0  -- just insert msg into MessageTarget for real user
				INSERT INTO dbo.MessageTarget (MessageId, LicenseeTypeId, PositionId)
				SELECT	@MessageId, LicenseeTypeId, 0
				FROM	dbo.f_LicenseeBelongToUser(@UserId)
				WHERE	LicenseeId IN (SELECT val FROM dbo.strSplit(@SelectedLicensee,','))
				GROUP BY LicenseeTypeId
		END				
	END TRY
	BEGIN CATCH
			DELETE FROM dbo.MessageTarget WITH(ROWLOCK, UPDLOCK)
			WHERE MessageId = @MessageId
			
			DELETE FROM dbo.LicenseeMessage WITH(ROWLOCK, UPDLOCK)
			WHERE MessageId = @MessageId
			
			DELETE FROM dbo.Message WITH(ROWLOCK, UPDLOCK)
			WHERE MessageId = @MessageId
			
			SELECT	@Errcode = 100
					,@ErrMsg = dbo.f_Get_MsgNamebyMsgID(40000,@Language)
			
			RETURN
	END CATCH
	
	-- write log
		
	SET @xml = (
		SELECT	@MessageTypeId		AS '@mid'
				,@log_Licensee		AS '@lt'			
		FOR XML PATH('r'), TYPE
		)		
				
	SELECT	@logSPData		= CONVERT(NVARCHAR(MAX),@xml)
			,@endRun		= GETDATE()  
			,@duration		= DATEDIFF(millisecond, @startRun, @endRun)   
			,@procName		= OBJECT_NAME(@@procid)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_ExternalNotificationListSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_ExternalNotificationListSel    Script Date: 12/11/2015 12:57:08 PM ******/
CREATE PROCEDURE [dbo].[OIC_ExternalNotificationListSel]
	@MessageTypeId		TINYINT			= 0
	,@FromDate			DATETIME 
	,@ToDate			DATETIME 
	,@UserId			INT
	,@Sender			VARCHAR(1000)	= 'All'
	,@SelectedLicensee	VARCHAR(MAX)	= 'All'
	,@SortBy			BIT				= 0
	,@Language			VARCHAR(10)		= 'All'
	
	,@PageSize			INT				= 10
	,@PageIndex			INT				= 0
	,@TotalRecords		INT				= 0		OUTPUT
	
	
AS
/*
	Created by: Kathy
	Date: 20150731
	Task: External notification list [Redmine:#40305]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	Param's Explanation:
		@SortBy:	0: Message Type ASC
					1: created time DESC
					
		@Language:	All - En + Ch + Cs
					En - English
					Ch - Traditional Chinese
					Cs - Simplified Chinese
 */
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RowStart	INT
			,@RowEnd	INT
	
	DECLARE @tblMessageType TABLE (MessageTypeId TINYINT, MessageTypeName VARCHAR(50))
	
	DECLARE @tblSender TABLE (UserId INT)
	DECLARE @tblSelectedLicensee TABLE (LicenseeId INT)
	
	CREATE TABLE #tblMessage (
		MessageId		INT PRIMARY KEY
		,MessageTypeId	TINYINT
		,ToList			NVARCHAR(MAX)
	)
	
	SELECT	@PageIndex	= @PageIndex 
			,@RowStart	= @PageSize * @PageIndex + 1
			,@RowEnd	= @RowStart + @PageSize - 1
			
	IF @MessageTypeId = 0 -- external + email
	BEGIN
		INSERT INTO @tblMessageType (MessageTypeId, MessageTypeName)
		EXEC dbo.OIC_MessageTypeSel @Mode = 4 
	END
	ELSE
	BEGIN
		INSERT INTO @tblMessageType (MessageTypeId, MessageTypeName)
		SELECT	MessageTypeId, MessageTypeName
		FROM	dbo.MessageType WITH(NOLOCK)
		WHERE	MessageTypeId = @MessageTypeId
	END
	
	IF @Sender <> 'All'
	BEGIN
		INSERT INTO @tblSender (UserId)
		SELECT	val 
		FROM	dbo.strSplit(@Sender, ',')
	END		
	
	IF @SelectedLicensee <> 'All'
	BEGIN
		INSERT INTO @tblSelectedLicensee (LicenseeId)
		SELECT	val 
		FROM	dbo.strSplit(@SelectedLicensee, ',')
	END		
	
	 -- public, special
	INSERT INTO #tblMessage (MessageId, MessageTypeId)		
	SELECT	m.MessageId, m.MessageTypeId
	FROM	dbo.Message m WITH(NOLOCK)
		INNER JOIN dbo.LicenseeMessage l WITH(NOLOCK)
			ON m.MessageId = l.MessageId
	WHERE	m.MessageTypeId IN (SELECT MessageTypeId FROM @tblMessageType WHERE MessageTypeId IN (40,41))
			AND m.CreateTime BETWEEN @FromDate AND @ToDate
			AND (m.Creator IN (SELECT UserId FROM @tblSender) 
				OR @Sender = 'All'
				)
			AND (@SelectedLicensee = 'All' 
				OR l.LicenseeId IN (SELECT LicenseeId FROM @tblSelectedLicensee)
				)
	GROUP BY m.MessageId, m.MessageTypeId
	
	SET @TotalRecords = @@rowcount
	
	-- for new user
	;WITH cteMessage 
	AS
	(
		SELECT	m.MessageId, m.MessageTypeId
		FROM	dbo.Message m WITH(NOLOCK)
			INNER JOIN dbo.MessageTarget mt WITH(NOLOCK)
				ON m.MessageId = mt.MessageId
		WHERE	m.MessageTypeId IN (SELECT MessageTypeId FROM @tblMessageType WHERE MessageTypeId IN (40,41))				
				AND m.CreateTime BETWEEN @FromDate AND @ToDate
				AND (m.Creator IN (SELECT UserId FROM @tblSender) 
					OR @Sender = 'All'
					)	
		GROUP BY m.MessageId, m.MessageTypeId		
	)
	INSERT INTO #tblMessage (MessageId, MessageTypeId)		
	SELECT	MessageId, MessageTypeId
	FROM	cteMessage c
	WHERE	MessageId NOT IN (SELECT MessageId FROM #tblMessage)
	
	SET @TotalRecords = @TotalRecords + @@rowcount
	
	-------------------------------	
	-- match delay-new, match delay-done, personal
	INSERT INTO #tblMessage (MessageId, MessageTypeId)		
	SELECT	m.MessageId, m.MessageTypeId
	FROM	dbo.Message m WITH(NOLOCK)
		INNER JOIN dbo.LicenseeMessage l WITH(NOLOCK)
			ON m.MessageId = l.MessageId
		INNER JOIN dbo.f_LicenseeBelongToUser (@UserId) f
			ON f.LicenseeId = l.LicenseeId
	WHERE	(m.MessageTypeId = @MessageTypeId
				OR @MessageTypeId = 0)
			AND m.MessageTypeId IN (SELECT MessageTypeId FROM @tblMessageType WHERE MessageTypeId IN(42, 43, 44, 60))
			AND m.CreateTime BETWEEN @FromDate AND @ToDate
			AND (m.Creator IN (SELECT UserId FROM @tblSender) 
				OR @Sender = 'All'
				)
			AND (@SelectedLicensee = 'All' 
				OR l.LicenseeId IN (SELECT LicenseeId FROM @tblSelectedLicensee)
				)
			AND m.MessageId NOT IN (SELECT MessageId FROM #tblMessage)
	GROUP BY m.MessageId, m.MessageTypeId
				
	SET @TotalRecords = @TotalRecords + @@rowcount
			
	-- for new user
	;WITH cteMessageTarget
	AS
	(
		SELECT	m.MessageId, m.MessageTypeId
		FROM	dbo.Message m WITH(NOLOCK)
			INNER JOIN dbo.MessageTarget mt WITH(NOLOCK)
				ON m.MessageId = mt.MessageId
		WHERE	(m.MessageTypeId = @MessageTypeId 
					OR @MessageTypeId = 0)
				AND m.MessageTypeId IN (SELECT MessageTypeId FROM @tblMessageType )				
				AND m.CreateTime BETWEEN @FromDate AND @ToDate
				AND (m.Creator IN (SELECT UserId FROM @tblSender) 
					OR @Sender = 'All'
					)			
				AND mt.LicenseeTypeId IN (SELECT LicenseeTypeId FROM dbo.f_LicenseeTypeBelongToUser (@UserId))
		GROUP BY m.MessageId, m.MessageTypeId
	)
	
	INSERT INTO #tblMessage (MessageId, MessageTypeId)		
	SELECT	MessageId, MessageTypeId
	FROM	cteMessageTarget c
	WHERE	MessageId NOT IN (SELECT MessageId FROM #tblMessage)
		
	SET @TotalRecords = @TotalRecords + @@rowcount
	
	-- get tolist if messagetype is personal. match- delay
	;WITH ctePersonalMessage
	AS(
		SELECT t.MessageId, STUFF((SELECT ', ' + l.LicenseeName
								FROM	dbo.LicenseeMessage lm WITH(NOLOCK)
									INNER JOIN dbo.Licensee l WITH(NOLOCK)
										ON l.LicenseeId = lm.LicenseeId
								WHERE	lm.MessageId = t.MessageId
								FOR XML PATH ('')
						),1,1,'') AS ToList
		FROM	#tblMessage t
		WHERE	t.MessageTypeId IN (42, 43, 44, 60) -- personal, match delay, email
		GROUP BY t.MessageId
	)
	UPDATE	t 
		SET	t.ToList = c.ToList 
	FROM	#tblMessage t
		INNER JOIN ctePersonalMessage c 
			ON t.MessageId = c.MessageId
			
	IF @Language <> 'All'
	BEGIN
		SELECT  MessageId
				,MessageTypeId
				,(SELECT MessageTypeName FROM dbo.MessageType WITH(NOLOCK) WHERE MessageTypeId = Result.MessageTypeId) AS MessageTypeName
				,CreateTime
				,Sender
				,ToList
				,Subject
				,Content				
		FROM
		(
			SELECT 	ROW_NUMBER() OVER(ORDER BY CASE WHEN @SortBy = 0 THEN m.MessageTypeId END ASC 
												,CreateTime DESC) AS RowNumber
					,m.MessageId
					,m.MessageTypeId
					,m.CreateTime
					,(SELECT DisplayName FROM dbo.UserInfo WITH(NOLOCK) WHERE UserId = m.Creator) AS Sender
					,t.ToList
					,CASE WHEN @Language = 'Ch' AND ISNULL(m.SubjectCh, '') <> '' THEN m.SubjectCh
						WHEN @Language = 'Cs' AND ISNULL(m.SubjectCs, '') <> '' THEN m.SubjectCs
						ELSE m.SubjectEn 
						END AS Subject
					,CASE WHEN @Language = 'Ch' AND ISNULL(m.ContentCh, '') <> '' THEN m.ContentCh
						WHEN @Language = 'Cs' AND ISNULL(m.ContentCs, '') <> '' THEN m.ContentCs
						ELSE m.ContentEn
						END AS Content					
			FROM	dbo.Message m WITH(NOLOCK)
				INNER JOIN #tblMessage t 
					ON m.MessageId = t.MessageId
		) AS Result
		WHERE RowNumber BETWEEN @RowStart AND @RowEnd
	END
	ELSE
	BEGIN
		SELECT  MessageId
				,MessageTypeId
				,(SELECT MessageTypeName FROM dbo.MessageType WITH(NOLOCK) WHERE MessageTypeId = Result.MessageTypeId) AS MessageTypeName
				,CreateTime
				,Sender
				,ToList
				,SubjectEn
				,SubjectCh
				,SubjectCs
				,ContentEn	
				,ContentCh
				,ContentCs	
		FROM
		(
			SELECT 	ROW_NUMBER() OVER(ORDER BY CASE WHEN @SortBy = 0 THEN m.MessageTypeId END ASC 
												,CreateTime DESC) AS RowNumber
					,m.MessageId
					,m.MessageTypeId
					,m.CreateTime
					,(SELECT DisplayName FROM dbo.UserInfo WITH(NOLOCK) WHERE UserId = m.Creator) AS Sender
					,t.ToList
					,m.SubjectEn
					,m.SubjectCh
					,m.SubjectCs
					,m.ContentEn
					,m.ContentCh
					,m.ContentCs	
			FROM	dbo.Message m WITH(NOLOCK)
				INNER JOIN #tblMessage t 
					ON m.MessageId = t.MessageId
		) AS Result
		WHERE RowNumber BETWEEN @RowStart AND @RowEnd
	END
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_FeatureDel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_FeatureDel    Script Date: 11/21/2016 10:54:16 PM ******/
/****** Object:  Stored Procedure dbo.OIC_FeatureDel    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_FeatureDel] 
	@FeatureId				TINYINT
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: delete feature [Redmine:#44252]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		
 */
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
	
	DECLARE @FeatureName VARCHAR(100)

	SET @startRun = GETDATE()		
	
	SELECT	@FeatureName = FeatureName
	FROM	dbo.Feature WITH(NOLOCK)
	WHERE	FeatureId = @FeatureId
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.LicenseeFeature WITH(NOLOCK) WHERE FeatureId = @FeatureId)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30019, @Language) -- Unable to delete the client feature because one or many assigned client(s) exist(s)
		RETURN
	END
	
	BEGIN TRY
		DELETE
		FROM	dbo.Feature WITH(ROWLOCK, UPDLOCK)
		WHERE	FeatureId = @FeatureId
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30020, @Language) -- Fail to delete client feature. Please try again.
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	@FeatureId		AS '@fi'
				,@FeatureName	AS '@fn'
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

		EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= NULL
		,@OldData		= @logSPData
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_FeatureDel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_FeatureDel_xtest    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_FeatureDel_xtest] 
	@FeatureId				TINYINT
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: delete feature [Redmine:#44252]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		
 */
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
	
	DECLARE @FeatureName VARCHAR(100)

	SET @startRun = GETDATE()		
	
	SELECT	@FeatureName = FeatureName
	FROM	dbo.Feature WITH(NOLOCK)
	WHERE	FeatureId = @FeatureId
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.LicenseeFeature WITH(NOLOCK) WHERE FeatureId = @FeatureId)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30019, @Language) -- Unable to delete the client feature because one or many assigned client(s) exist(s)
		RETURN
	END
	
	BEGIN TRY
		DELETE
		FROM	dbo.Feature WITH(ROWLOCK, UPDLOCK)
		WHERE	FeatureId = @FeatureId
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30020, @Language) -- Fail to delete client feature. Please try again.
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	@FeatureId		AS '@fi'
				,@FeatureName	AS '@fn'
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= NULL
		,@OldData		= @logSPData
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_FeatureIns]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_FeatureIns    Script Date: 11/21/2016 10:54:16 PM ******/
/****** Object:  Stored Procedure dbo.OIC_FeatureIns    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_FeatureIns] 
	@FeatureName			VARCHAR(300)
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: insert new feature [Redmine:#44252]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		
*/
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)

	DECLARE @FeatureId TINYINT

	SET @startRun = GETDATE()		
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.Feature WITH(NOLOCK) WHERE FeatureName =@FeatureName)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30016, @Language) -- The feature name is already used. Please try another name.
		RETURN
	END
	
	BEGIN TRY
		INSERT INTO dbo.Feature (FeatureName) VALUES (@FeatureName)
	
		SET @FeatureId = SCOPE_IDENTITY()
	
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30017, @Language) -- Fail to create client feature. Please try again.
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	@FeatureId		AS '@fi'
				,@FeatureName	AS '@fn'
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

		EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_FeatureIns_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_FeatureIns_xtest    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_FeatureIns_xtest] 
	@FeatureName			VARCHAR(300)
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: insert new feature [Redmine:#44252]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		
*/
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)

	DECLARE @FeatureId TINYINT

	SET @startRun = GETDATE()		
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.Feature WITH(NOLOCK) WHERE FeatureName =@FeatureName)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30016, @Language) -- The feature name is already used. Please try another name.
		RETURN
	END
	
	BEGIN TRY
		INSERT INTO dbo.Feature (FeatureName) VALUES (@FeatureName)
	
		SET @FeatureId = SCOPE_IDENTITY()
	
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30017, @Language) -- Fail to create client feature. Please try again.
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	@FeatureId		AS '@fi'
				,@FeatureName	AS '@fn'
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_FeatureSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_FeatureSel    Script Date: 11/21/2016 10:55:02 PM ******/
/****** Object:  Stored Procedure dbo.OIC_FeatureSel    Script Date: 11/17/2016 2:56:34 PM ******/

CREATE PROCEDURE [dbo].[OIC_FeatureSel] 
AS
/*
	Created by: Kathy
	Date: 2014-12-25
	Task: Get feature list [Redmine:#27752]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		
 */
BEGIN
	SET NOCOUNT ON
	
	SELECT FeatureId
			,FeatureName
	FROM dbo.Feature WITH(NOLOCK)
	ORDER BY FeatureId
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_FeatureSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_FeatureSel_xtest    Script Date: 11/17/2016 2:56:34 PM ******/

CREATE PROCEDURE [dbo].[OIC_FeatureSel_xtest] 
AS
/*
	Created by: Kathy
	Date: 2014-12-25
	Task: Get feature list [Redmine:#27752]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		
 */
BEGIN
	SET NOCOUNT ON
	
	SELECT FeatureId
			,FeatureName
	FROM dbo.Feature WITH(NOLOCK)
	ORDER BY FeatureId
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_FeatureUpd]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_FeatureUpd    Script Date: 11/21/2016 10:54:17 PM ******/
/****** Object:  Stored Procedure dbo.OIC_FeatureUpd    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_FeatureUpd] 
	@FeatureId				TINYINT
	,@FeatureName			VARCHAR(300)
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: update feature [Redmine:#44252]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		
 */
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPOlddata	NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)

	SET @startRun = GETDATE()
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.Feature WITH(NOLOCK) WHERE FeatureName = @FeatureName)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30016,@Language) -- The feature name is already used. Please try another name.
		RETURN
	END		
	
	-- get old data
	SET @xml = (
		SELECT	FeatureId		AS '@fi'
				,FeatureName	AS '@fn'
		FROM	dbo.Feature WITH(NOLOCK)
		WHERE	FeatureId = @FeatureId
		FOR XML PATH('r'), TYPE
		)		
	
	SELECT @logSPOlddata = CONVERT(NVARCHAR(MAX), @xml)
					
	BEGIN TRY
		UPDATE	dbo.Feature WITH(ROWLOCK, UPDLOCK)
			SET	FeatureName = @FeatureName
		WHERE	FeatureId = @FeatureId	
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30018, @Language) -- Fail to edit client feature. Please try again.	
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	FeatureId		AS '@fi'
				,FeatureName	AS '@fn'
		FROM	dbo.Feature WITH(NOLOCK)
		WHERE	FeatureId = @FeatureId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

		EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOlddata
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_FeatureUpd_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_FeatureUpd_xtest    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_FeatureUpd_xtest] 
	@FeatureId				TINYINT
	,@FeatureName			VARCHAR(300)
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: update feature [Redmine:#44252]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		
 */
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPOlddata	NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)

	SET @startRun = GETDATE()
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.Feature WITH(NOLOCK) WHERE FeatureName = @FeatureName)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30016,@Language) -- The feature name is already used. Please try another name.
		RETURN
	END		
	
	-- get old data
	SET @xml = (
		SELECT	FeatureId		AS '@fi'
				,FeatureName	AS '@fn'
		FROM	dbo.Feature WITH(NOLOCK)
		WHERE	FeatureId = @FeatureId
		FOR XML PATH('r'), TYPE
		)		
	
	SELECT @logSPOlddata = CONVERT(NVARCHAR(MAX), @xml)
					
	BEGIN TRY
		UPDATE	dbo.Feature WITH(ROWLOCK, UPDLOCK)
			SET	FeatureName = @FeatureName
		WHERE	FeatureId = @FeatureId	
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30018, @Language) -- Fail to edit client feature. Please try again.	
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	FeatureId		AS '@fi'
				,FeatureName	AS '@fn'
		FROM	dbo.Feature WITH(NOLOCK)
		WHERE	FeatureId = @FeatureId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOlddata
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_InternalNotificationIns]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_InternalNotificationIns    Script Date: 3/13/2017 11:46:31 PM ******/
/****** Object:  Stored Procedure dbo.OIC_InternalNotificationIns    Script Date: 3/2/2017 10:06:15 AM ******/

CREATE PROCEDURE [dbo].[OIC_InternalNotificationIns] 
	@MessageTypeId			TINYINT
	,@SelectedLicenseeType	VARCHAR(100)	= ''
	,@SelectedRecipient		VARCHAR(1000)	= ''
	,@SubjectEn				NVARCHAR(300)
	,@ContentEn				NVARCHAR(MAX)	= ''
	
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150730
	Task: Insert internal notification [Redmine:#40305]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20170302@Percy: Expand length of Content [RedmineID: #70322]
	
	Param's Explanation:
		@MessageTypeId: 1: News-Manual --> send to all user
						21: Important-Manual --> send to all user belong to seleted licensee type
						20: 1on1 --> send to 1on1 user
						23: Private --> send to seleted user
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @startRun		DATETIME
			,@endRun		DATETIME
			,@duration		INT
			,@logSPData		NVARCHAR(MAX)
			,@xml			XML
			,@procName		VARCHAR(200)
			,@MessageId		INT 
			,@IsTesting		BIT = 0	
	
	DECLARE @tblUser TABLE (UserId INT)
			
	SET @startRun = GETDATE()
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE DisplayName LIKE 'starix%' AND UserId = @UserId)
		SET @IsTesting = 1
		
	IF @MessageTypeId = 21  -- Important-Manual
	BEGIN
		IF ISNULL(@SelectedLicenseeType, '') = ''
			RETURN
			
		INSERT INTO @tblUser (UserId)
		SELECT	UserId
		FROM	dbo.UserLicenseeType WITH(NOLOCK)
		WHERE	LicenseeTypeId IN (SELECT val FROM dbo.strSplit(@SelectedLicenseeType, ','))
		GROUP BY UserId
	END
	ELSE IF @MessageTypeId IN (1, 20) -- 1: News-Manual, 20: 1on1
	BEGIN
		INSERT INTO @tblUser(UserId)
		SELECT	UserId
		FROM	dbo.UserInfo WITH(NOLOCK)
		WHERE	PositionId = CASE WHEN @MessageTypeId = 22 THEN 4 ELSE PositionId END
	END
	ELSE IF @MessageTypeId = 23 -- Private
	BEGIN
		IF ISNULL(@SelectedRecipient, '') = ''
			RETURN
			
		INSERT INTO @tblUser(UserId)
		SELECT val
		FROM dbo.strSplit(@SelectedRecipient,',')
		UNION
		SELECT @UserId
	END
	
	BEGIN TRY
		INSERT INTO dbo.Message (SubjectEn, ContentEn, MessageTypeId, Creator, CreateTime)
		SELECT	@SubjectEn, @ContentEn, @MessageTypeId, @UserId, GETDATE()
		
		SET @MessageId = SCOPE_IDENTITY()
		
		INSERT INTO dbo.UserMessage (UserId, MessageId, IsRead)
		SELECT	t.UserId, @MessageId, 0
		FROM	@tblUser t
				INNER JOIN dbo.UserInfo u WITH(NOLOCK)
					ON t.UserId = u.UserId
			WHERE	(@IsTesting = 0
						OR (@IsTesting = 1 AND u.DisplayName LIKE 'starix%')) -- if the msg for testing, dont send to real user
		
		IF @IsTesting = 0 -- just insert msg into MessageTarget for real user
		BEGIN
			IF @MessageTypeId IN (1, 20)  -- 1: News-Manual: send to all postions, 20: 1on1: send to 1on1
			BEGIN
				INSERT INTO dbo.MessageTarget (MessageId, LicenseeTypeId, PositionId)
				SELECT	@MessageId
						,0
						,PositionId
				FROM	dbo.Position WITH(NOLOCK)
				WHERE	PositionId = CASE WHEN @MessageTypeId = 20 THEN 4 ELSE PositionId END
			END
			ELSE IF @MessageTypeId = 21 -- Important-Manual
			BEGIN
				INSERT INTO dbo.MessageTarget (MessageId, LicenseeTypeId, PositionId)
				SELECT	@MessageId
						,val AS LicenseeTypeId
						,0
				FROM	dbo.strSplit(@SelectedLicenseeType, ',') 
			END
		END	
		
	END TRY
	BEGIN CATCH
			DELETE FROM dbo.MessageTarget WITH(ROWLOCK, UPDLOCK)
			WHERE MessageId = @MessageId
			
			DELETE FROM dbo.UserMessage WITH(ROWLOCK, UPDLOCK)
			WHERE MessageId = @MessageId
			
			DELETE FROM dbo.Message WITH(ROWLOCK, UPDLOCK)
			WHERE MessageId = @MessageId
			
			SELECT	@Errcode = 100
					,@ErrMsg = dbo.f_Get_MsgNamebyMsgID(40000,@Language)
			
			RETURN
	END CATCH
	
	-- write log
	SET @xml = (
		SELECT	@MessageTypeId			AS '@mid'
				,@SelectedLicenseeType	AS '@lt'
				,@SelectedRecipient		AS '@sr'
				,@SubjectEn				AS '@sbe'
				,@ContentEn				AS '@ce'
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT	@logSPData		= CONVERT(NVARCHAR(MAX),@xml)
			,@endRun		= GETDATE()  
			,@duration		= DATEDIFF(millisecond, @startRun, @endRun)   
			,@procName		= OBJECT_NAME(@@procid)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_InternalNotificationIns_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_InternalNotificationIns_xtest    Script Date: 3/2/2017 10:06:15 AM ******/

CREATE PROCEDURE [dbo].[OIC_InternalNotificationIns_xtest] 
	@MessageTypeId			TINYINT
	,@SelectedLicenseeType	VARCHAR(100)	= ''
	,@SelectedRecipient		VARCHAR(1000)	= ''
	,@SubjectEn				NVARCHAR(300)
	,@ContentEn				NVARCHAR(MAX)	= ''
	
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150730
	Task: Insert internal notification [Redmine:#40305]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20170302@Percy: Expand length of Content [RedmineID: #70322]
	
	Param's Explanation:
		@MessageTypeId: 1: News-Manual --> send to all user
						21: Important-Manual --> send to all user belong to seleted licensee type
						20: 1on1 --> send to 1on1 user
						23: Private --> send to seleted user
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @startRun		DATETIME
			,@endRun		DATETIME
			,@duration		INT
			,@logSPData		NVARCHAR(MAX)
			,@xml			XML
			,@procName		VARCHAR(200)
			,@MessageId		INT 
			,@IsTesting		BIT = 0	
	
	DECLARE @tblUser TABLE (UserId INT)
			
	SET @startRun = GETDATE()
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE DisplayName LIKE 'starix%' AND UserId = @UserId)
		SET @IsTesting = 1
		
	IF @MessageTypeId = 21  -- Important-Manual
	BEGIN
		IF ISNULL(@SelectedLicenseeType, '') = ''
			RETURN
			
		INSERT INTO @tblUser (UserId)
		SELECT	UserId
		FROM	dbo.UserLicenseeType WITH(NOLOCK)
		WHERE	LicenseeTypeId IN (SELECT val FROM dbo.strSplit(@SelectedLicenseeType, ','))
		GROUP BY UserId
	END
	ELSE IF @MessageTypeId IN (1, 20) -- 1: News-Manual, 20: 1on1
	BEGIN
		INSERT INTO @tblUser(UserId)
		SELECT	UserId
		FROM	dbo.UserInfo WITH(NOLOCK)
		WHERE	PositionId = CASE WHEN @MessageTypeId = 22 THEN 4 ELSE PositionId END
	END
	ELSE IF @MessageTypeId = 23 -- Private
	BEGIN
		IF ISNULL(@SelectedRecipient, '') = ''
			RETURN
			
		INSERT INTO @tblUser(UserId)
		SELECT val
		FROM dbo.strSplit(@SelectedRecipient,',')
		UNION
		SELECT @UserId
	END
	
	BEGIN TRY
		INSERT INTO dbo.Message (SubjectEn, ContentEn, MessageTypeId, Creator, CreateTime)
		SELECT	@SubjectEn, @ContentEn, @MessageTypeId, @UserId, GETDATE()
		
		SET @MessageId = SCOPE_IDENTITY()
		
		INSERT INTO dbo.UserMessage (UserId, MessageId, IsRead)
		SELECT	t.UserId, @MessageId, 0
		FROM	@tblUser t
				INNER JOIN dbo.UserInfo u WITH(NOLOCK)
					ON t.UserId = u.UserId
			WHERE	(@IsTesting = 0
						OR (@IsTesting = 1 AND u.DisplayName LIKE 'starix%')) -- if the msg for testing, dont send to real user
		
		IF @IsTesting = 0 -- just insert msg into MessageTarget for real user
		BEGIN
			IF @MessageTypeId IN (1, 20)  -- 1: News-Manual: send to all postions, 20: 1on1: send to 1on1
			BEGIN
				INSERT INTO dbo.MessageTarget (MessageId, LicenseeTypeId, PositionId)
				SELECT	@MessageId
						,0
						,PositionId
				FROM	dbo.Position WITH(NOLOCK)
				WHERE	PositionId = CASE WHEN @MessageTypeId = 20 THEN 4 ELSE PositionId END
			END
			ELSE IF @MessageTypeId = 21 -- Important-Manual
			BEGIN
				INSERT INTO dbo.MessageTarget (MessageId, LicenseeTypeId, PositionId)
				SELECT	@MessageId
						,val AS LicenseeTypeId
						,0
				FROM	dbo.strSplit(@SelectedLicenseeType, ',') 
			END
		END	
		
	END TRY
	BEGIN CATCH
			DELETE FROM dbo.MessageTarget WITH(ROWLOCK, UPDLOCK)
			WHERE MessageId = @MessageId
			
			DELETE FROM dbo.UserMessage WITH(ROWLOCK, UPDLOCK)
			WHERE MessageId = @MessageId
			
			DELETE FROM dbo.Message WITH(ROWLOCK, UPDLOCK)
			WHERE MessageId = @MessageId
			
			SELECT	@Errcode = 100
					,@ErrMsg = dbo.f_Get_MsgNamebyMsgID(40000,@Language)
			
			RETURN
	END CATCH
	
	-- write log
	SET @xml = (
		SELECT	@MessageTypeId			AS '@mid'
				,@SelectedLicenseeType	AS '@lt'
				,@SelectedRecipient		AS '@sr'
				,@SubjectEn				AS '@sbe'
				,@ContentEn				AS '@ce'
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT	@logSPData		= CONVERT(NVARCHAR(MAX),@xml)
			,@endRun		= GETDATE()  
			,@duration		= DATEDIFF(millisecond, @startRun, @endRun)   
			,@procName		= OBJECT_NAME(@@procid)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_InternalNotificationListSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_InternalNotificationListSel    Script Date: 3/13/2017 11:46:32 PM ******/
/****** Object:  Stored Procedure dbo.OIC_InternalNotificationListSel    Script Date: 3/2/2017 10:06:15 AM ******/

CREATE PROCEDURE [dbo].[OIC_InternalNotificationListSel]
	@MessageTypeId	TINYINT			= 0
	,@FromDate		DATETIME 
	,@ToDate		DATETIME 
	,@UserId		INT
	,@Sender		VARCHAR(MAX)	= 'All'
	,@ReadStatus	SMALLINT		= 2 -- ALL
	,@SortBy		BIT				= 0
	
	,@PageSize		INT				= 10
	,@PageIndex		INT				= 0
	,@TotalRecords	INT				= 0 OUTPUT
	
	
AS
/*
	Created by: Kathy
	Date: 20150731
	Task: Internal notification list [Redmine:#40305]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20161216@Percy: Support sort message type [RedmineID: #68774]
		- 20170302@Percy: Expand length of Content [RedmineID: #70322]

	
	Param's Explanation:
		@ReadStatus: 0: un-read
					 1: read
					 2: ALL	
		@SortBy: 0: Message Type ASC
				 1: created time DESC
 */
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RowStart	INT
			,@RowEnd	INT
	
	DECLARE @tblSender TABLE (UserId INT)
	DECLARE @tblLicenseeType TABLE (LicenseeTypeId TINYINT)
	DECLARE @PositionId	TINYINT 	
	CREATE TABLE #tblMessage(
		MessageId			INT PRIMARY KEY
		,MessageTypeId		TINYINT
		,ReminderTypeId		TINYINT
		,ReminderTypeValue	XML
		,CreateTime			DATETIME
		,Sender				NVARCHAR(50)
		,SubjectEn			NVARCHAR(300)
		,ContentEn			NVARCHAR(MAX)
		,IsRead				BIT
		,IsDisable			BIT
		,ToList				VARCHAR(MAX)
	)
	
	DECLARE @tblMessageType TABLE (MessageTypeId TINYINT, MessageTypeName VARCHAR(50))
	
	IF @MessageTypeId = 0 -- internal system + manual
	BEGIN
		INSERT INTO @tblMessageType (MessageTypeId, MessageTypeName)
				EXEC dbo.OIC_MessageTypeSel @Mode = 3
	END
	ELSE
	BEGIN
		INSERT INTO @tblMessageType (MessageTypeId, MessageTypeName)
		SELECT	MessageTypeId, MessageTypeName
		FROM	dbo.MessageType WITH(NOLOCK)
		WHERE	MessageTypeId = @MessageTypeId
	END
	
	SELECT	@PageIndex	= @PageIndex 
			,@RowStart	= @PageSize * @PageIndex + 1
			,@RowEnd	= @RowStart + @PageSize - 1
			
	SELECT	@PositionId = PositionId
	FROM	dbo.UserInfo WITH(NOLOCK)
	WHERE	UserId = @UserId
	
	INSERT INTO @tblLicenseeType (LicenseeTypeId)
	SELECT	LicenseeTypeId
	FROM	dbo.UserLicenseeType WITH(NOLOCK)
	WHERE	UserId = @UserId
	
	IF @Sender <> 'All'
	BEGIN
		INSERT INTO @tblSender (UserId)
		SELECT	val 
		FROM	dbo.strSplit(@Sender, ',')
	END	
	
	INSERT INTO #tblMessage(
			MessageId
			,MessageTypeId
			,ReminderTypeId
			,ReminderTypeValue
			,CreateTime
			,Sender
			,SubjectEn
			,ContentEn
			,IsRead
			,IsDisable
		)
	SELECT  m.MessageId
			,MessageTypeId
			,m.ReminderTypeId
			,m.ReminderTypeValue
			,m.CreateTime
			,CASE WHEN m.Creator <> 0 THEN (SELECT DisplayName FROM dbo.UserInfo WITH(NOLOCK) WHERE UserId = m.Creator) ELSE 'System' END AS Sender
			,m.SubjectEn
			,m.ContentEn
			,um.IsRead
			,0 AS IsDisable
	FROM	dbo.Message m WITH(NOLOCK)
	INNER JOIN dbo.UserMessage um WITH(NOLOCK)
		ON	m.MessageId = um.MessageId
	WHERE	(m.MessageTypeId = @MessageTypeId 
				OR @MessageTypeId = 0)
			AND m.MessageTypeId IN (SELECT MessageTypeId FROM @tblMessageType)
			AND m.CreateTime BETWEEN @FromDate AND @ToDate
			AND ( m.Creator IN (SELECT UserId FROM @tblSender) OR @Sender = 'All')
			AND um.UserId = @UserId
			AND (
				@ReadStatus = 2
				OR m.MessageTypeId = 24
				OR um.IsRead = @ReadStatus
			)
	
	SET @TotalRecords = @@rowcount
	
	IF @ReadStatus <> 0 -- unread
	BEGIN					
		;WITH cteMessageTarget
		AS(
			SELECT	m.MessageId
					,MessageTypeId
					,m.ReminderTypeId
					,m.ReminderTypeValue
					,m.CreateTime
					,CASE WHEN m.Creator <> 0 THEN (SELECT DisplayName FROM dbo.UserInfo WITH(NOLOCK) WHERE UserId = m.Creator) ELSE 'System' END AS Sender
					,m.SubjectEn
					,m.ContentEn
					,1 AS IsRead -- read
			FROM	dbo.Message m WITH(NOLOCK)
			INNER JOIN dbo.MessageTarget mt WITH(NOLOCK)
				ON	m.MessageId = mt.MessageId
			WHERE	(m.MessageTypeId = @MessageTypeId OR @MessageTypeId = 0)
					AND m.MessageTypeId IN (SELECT MessageTypeId FROM @tblMessageType)
					AND m.CreateTime BETWEEN @FromDate AND @ToDate
					AND ( m.Creator IN (SELECT UserId FROM @tblSender) OR @Sender = 'All')
					AND (mt.LicenseeTypeId IN (SELECT t.LicenseeTypeId FROM @tblLicenseeType t)
							OR mt.PositionId = @PositionId
						)
					AND m.MessageId NOT IN (SELECT MessageId FROM #tblMessage)
			--GROUP BY m.MessageId, MessageTypeId, CreateTime, m.Creator, SubjectEn, ContentEn,m.ReminderTypeId,ISNULL(m.ReminderTypeValue, '')
		)
		INSERT INTO #tblMessage(
			MessageId			
			,MessageTypeId
			,ReminderTypeId
			,ReminderTypeValue
			,CreateTime	
			,Sender		
			,SubjectEn			
			,ContentEn			
			,IsRead		
			,IsDisable		
		)
		SELECT	MessageId	
				,MessageTypeId
				,ReminderTypeId
				,ReminderTypeValue	
				,CreateTime	
				,Sender		
				,SubjectEn			
				,ContentEn			
				,IsRead	
				,1 -- always disable old messages for the new authorized user
		FROM cteMessageTarget
	
		SET @TotalRecords = @TotalRecords + @@rowcount
	END
	
	-- get tolist if messagetype is private
	;WITH ctePrivateMessage
	AS(
		SELECT t.MessageId, STUFF((SELECT ', ' + u.DisplayName
								FROM	dbo.UserMessage lm WITH(NOLOCK)					
									INNER JOIN dbo.UserInfo u WITH(NOLOCK)
										ON u.UserId = lm.UserId
								WHERE	lm.MessageId = t.MessageId
								FOR XML PATH ('')
						),1,1,'') AS ToList
		FROM	#tblMessage t
		WHERE	t.MessageTypeId = 23 -- Private
		GROUP BY t.MessageId
	)
	
	UPDATE t
		SET t.ToList = c.ToList
	FROM #tblMessage t
		INNER JOIN ctePrivateMessage c
			ON t.MessageId = c.MessageId
	
	SELECT	MessageId
			,MessageTypeId
			,MessageTypeName
			,ReminderTypeId
			,ReminderTypeName
			,ReminderTypeValue
			,CreateTime
			,Sender
			,SubjectEn
			,ContentEn
			,IsRead
			,IsDisable
			,ToList
	FROM(
		SELECT	ROW_NUMBER() OVER(ORDER BY CASE WHEN @SortBy = 0 THEN mt.[Order] END ASC ,CreateTime DESC) AS RowNumber
				,MessageId
				,mt.MessageTypeId
				,mt.MessageTypeName
				,m.ReminderTypeId
				,m.ReminderTypeValue
				,rt.ReminderTypeName
				,CreateTime
				,Sender
				,SubjectEn
				,ContentEn
				,IsRead
				,IsDisable
				,ToList
		FROM #tblMessage m
			INNER JOIN dbo.MessageType mt WITH (NOLOCK) ON m.MessageTypeId = mt.MessageTypeId
			LEFT JOIN dbo.ReminderType rt WITH(NOLOCK) ON m.ReminderTypeId = rt.ReminderTypeId
	) Result
	WHERE RowNumber BETWEEN @RowStart AND @RowEnd
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_InternalNotificationListSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_InternalNotificationListSel_xtest    Script Date: 3/2/2017 10:06:15 AM ******/

CREATE PROCEDURE [dbo].[OIC_InternalNotificationListSel_xtest]
	@MessageTypeId	TINYINT			= 0
	,@FromDate		DATETIME 
	,@ToDate		DATETIME 
	,@UserId		INT
	,@Sender		VARCHAR(MAX)	= 'All'
	,@ReadStatus	SMALLINT		= 2 -- ALL
	,@SortBy		BIT				= 0
	
	,@PageSize		INT				= 10
	,@PageIndex		INT				= 0
	,@TotalRecords	INT				= 0 OUTPUT
	
	
AS
/*
	Created by: Kathy
	Date: 20150731
	Task: Internal notification list [Redmine:#40305]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20161216@Percy: Support sort message type [RedmineID: #68774]
		- 20170302@Percy: Expand length of Content [RedmineID: #70322]

	
	Param's Explanation:
		@ReadStatus: 0: un-read
					 1: read
					 2: ALL	
		@SortBy: 0: Message Type ASC
				 1: created time DESC
 */
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RowStart	INT
			,@RowEnd	INT
	
	DECLARE @tblSender TABLE (UserId INT)
	DECLARE @tblLicenseeType TABLE (LicenseeTypeId TINYINT)
	DECLARE @PositionId	TINYINT 	
	CREATE TABLE #tblMessage(
		MessageId			INT PRIMARY KEY
		,MessageTypeId		TINYINT
		,ReminderTypeId		TINYINT
		,ReminderTypeValue	XML
		,CreateTime			DATETIME
		,Sender				NVARCHAR(50)
		,SubjectEn			NVARCHAR(300)
		,ContentEn			NVARCHAR(MAX)
		,IsRead				BIT
		,IsDisable			BIT
		,ToList				VARCHAR(MAX)
	)
	
	DECLARE @tblMessageType TABLE (MessageTypeId TINYINT, MessageTypeName VARCHAR(50))
	
	IF @MessageTypeId = 0 -- internal system + manual
	BEGIN
		INSERT INTO @tblMessageType (MessageTypeId, MessageTypeName)
				EXEC dbo.OIC_MessageTypeSel @Mode = 3
	END
	ELSE
	BEGIN
		INSERT INTO @tblMessageType (MessageTypeId, MessageTypeName)
		SELECT	MessageTypeId, MessageTypeName
		FROM	dbo.MessageType WITH(NOLOCK)
		WHERE	MessageTypeId = @MessageTypeId
	END
	
	SELECT	@PageIndex	= @PageIndex 
			,@RowStart	= @PageSize * @PageIndex + 1
			,@RowEnd	= @RowStart + @PageSize - 1
			
	SELECT	@PositionId = PositionId
	FROM	dbo.UserInfo WITH(NOLOCK)
	WHERE	UserId = @UserId
	
	INSERT INTO @tblLicenseeType (LicenseeTypeId)
	SELECT	LicenseeTypeId
	FROM	dbo.UserLicenseeType WITH(NOLOCK)
	WHERE	UserId = @UserId
	
	IF @Sender <> 'All'
	BEGIN
		INSERT INTO @tblSender (UserId)
		SELECT	val 
		FROM	dbo.strSplit(@Sender, ',')
	END	
	
	INSERT INTO #tblMessage(
			MessageId
			,MessageTypeId
			,ReminderTypeId
			,ReminderTypeValue
			,CreateTime
			,Sender
			,SubjectEn
			,ContentEn
			,IsRead
			,IsDisable
		)
	SELECT  m.MessageId
			,MessageTypeId
			,m.ReminderTypeId
			,m.ReminderTypeValue
			,m.CreateTime
			,CASE WHEN m.Creator <> 0 THEN (SELECT DisplayName FROM dbo.UserInfo WITH(NOLOCK) WHERE UserId = m.Creator) ELSE 'System' END AS Sender
			,m.SubjectEn
			,m.ContentEn
			,um.IsRead
			,0 AS IsDisable
	FROM	dbo.Message m WITH(NOLOCK)
	INNER JOIN dbo.UserMessage um WITH(NOLOCK)
		ON	m.MessageId = um.MessageId
	WHERE	(m.MessageTypeId = @MessageTypeId 
				OR @MessageTypeId = 0)
			AND m.MessageTypeId IN (SELECT MessageTypeId FROM @tblMessageType)
			AND m.CreateTime BETWEEN @FromDate AND @ToDate
			AND ( m.Creator IN (SELECT UserId FROM @tblSender) OR @Sender = 'All')
			AND um.UserId = @UserId
			AND (
				@ReadStatus = 2
				OR m.MessageTypeId = 24
				OR um.IsRead = @ReadStatus
			)
	
	SET @TotalRecords = @@rowcount
	
	IF @ReadStatus <> 0 -- unread
	BEGIN					
		;WITH cteMessageTarget
		AS(
			SELECT	m.MessageId
					,MessageTypeId
					,m.ReminderTypeId
					,m.ReminderTypeValue
					,m.CreateTime
					,CASE WHEN m.Creator <> 0 THEN (SELECT DisplayName FROM dbo.UserInfo WITH(NOLOCK) WHERE UserId = m.Creator) ELSE 'System' END AS Sender
					,m.SubjectEn
					,m.ContentEn
					,1 AS IsRead -- read
			FROM	dbo.Message m WITH(NOLOCK)
			INNER JOIN dbo.MessageTarget mt WITH(NOLOCK)
				ON	m.MessageId = mt.MessageId
			WHERE	(m.MessageTypeId = @MessageTypeId OR @MessageTypeId = 0)
					AND m.MessageTypeId IN (SELECT MessageTypeId FROM @tblMessageType)
					AND m.CreateTime BETWEEN @FromDate AND @ToDate
					AND ( m.Creator IN (SELECT UserId FROM @tblSender) OR @Sender = 'All')
					AND (mt.LicenseeTypeId IN (SELECT t.LicenseeTypeId FROM @tblLicenseeType t)
							OR mt.PositionId = @PositionId
						)
					AND m.MessageId NOT IN (SELECT MessageId FROM #tblMessage)
			--GROUP BY m.MessageId, MessageTypeId, CreateTime, m.Creator, SubjectEn, ContentEn,m.ReminderTypeId,ISNULL(m.ReminderTypeValue, '')
		)
		INSERT INTO #tblMessage(
			MessageId			
			,MessageTypeId
			,ReminderTypeId
			,ReminderTypeValue
			,CreateTime	
			,Sender		
			,SubjectEn			
			,ContentEn			
			,IsRead		
			,IsDisable		
		)
		SELECT	MessageId	
				,MessageTypeId
				,ReminderTypeId
				,ReminderTypeValue	
				,CreateTime	
				,Sender		
				,SubjectEn			
				,ContentEn			
				,IsRead	
				,1 -- always disable old messages for the new authorized user
		FROM cteMessageTarget
	
		SET @TotalRecords = @TotalRecords + @@rowcount
	END
	
	-- get tolist if messagetype is private
	;WITH ctePrivateMessage
	AS(
		SELECT t.MessageId, STUFF((SELECT ', ' + u.DisplayName
								FROM	dbo.UserMessage lm WITH(NOLOCK)					
									INNER JOIN dbo.UserInfo u WITH(NOLOCK)
										ON u.UserId = lm.UserId
								WHERE	lm.MessageId = t.MessageId
								FOR XML PATH ('')
						),1,1,'') AS ToList
		FROM	#tblMessage t
		WHERE	t.MessageTypeId = 23 -- Private
		GROUP BY t.MessageId
	)
	
	UPDATE t
		SET t.ToList = c.ToList
	FROM #tblMessage t
		INNER JOIN ctePrivateMessage c
			ON t.MessageId = c.MessageId
	
	SELECT	MessageId
			,MessageTypeId
			,MessageTypeName
			,ReminderTypeId
			,ReminderTypeName
			,ReminderTypeValue
			,CreateTime
			,Sender
			,SubjectEn
			,ContentEn
			,IsRead
			,IsDisable
			,ToList
	FROM(
		SELECT	ROW_NUMBER() OVER(ORDER BY CASE WHEN @SortBy = 0 THEN mt.[Order] END ASC ,CreateTime DESC) AS RowNumber
				,MessageId
				,mt.MessageTypeId
				,mt.MessageTypeName
				,m.ReminderTypeId
				,m.ReminderTypeValue
				,rt.ReminderTypeName
				,CreateTime
				,Sender
				,SubjectEn
				,ContentEn
				,IsRead
				,IsDisable
				,ToList
		FROM #tblMessage m
			INNER JOIN dbo.MessageType mt WITH (NOLOCK) ON m.MessageTypeId = mt.MessageTypeId
			LEFT JOIN dbo.ReminderType rt WITH(NOLOCK) ON m.ReminderTypeId = rt.ReminderTypeId
	) Result
	WHERE RowNumber BETWEEN @RowStart AND @RowEnd
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_InternalNotificationNewestList]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_InternalNotificationNewestList    Script Date: 2/9/2017 3:10:44 AM ******/
/****** Object:  Stored Procedure dbo.OIC_InternalNotificationNewestList    Script Date: 2/7/2017 9:24:52 AM ******/

CREATE PROCEDURE [dbo].[OIC_InternalNotificationNewestList] 
	@UserId		INT
	,@Mode		SMALLINT	= 0
	,@Top		INT			= 10	
	,@MessageId INT			= 0 
AS
/*
	Created by: Kathy
	Date: 20150803
	Task: notification detail [Redmine:#40305]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20161221@Percy: Implement Important - Reminder [RedmineID: #68774]
	
	Param's Explanation:
		@Mode:	0 - News
				1 - 1on1 team
				2 - Important
				3 - Private
				4 - Reminder
		@Top:	0 - ALL
				10 - 10 newest notification
				
		@MessageId:	0 - get all msg at the fist time
					max(messageid) - get more newest msg have id > max(messageid) since last call
		
 */
BEGIN
	SET NOCOUNT ON
	DECLARE @CurrentDateTime DATETIME
	SELECT  @CurrentDateTime = CONVERT(VARCHAR(8), DATEADD(HOUR, 12, GETDATE()), 114) + ' ' + CONVERT(VARCHAR(10), DATEADD(HOUR, 12, GETDATE()), 101) --convert time to GMT +8

	IF @Mode = 4 -- Reminder
	BEGIN
		SELECT m.MessageId
			,(SELECT MessageTypeName FROM dbo.MessageType WITH(NOLOCK) WHERE MessageTypeId = m.MessageTypeId) AS MessageTypeName
			,CASE WHEN m.Creator <> 0 THEN (SELECT DisplayName FROM dbo.UserInfo WITH(NOLOCK) WHERE UserId = m.Creator) ELSE 'System' END AS Sender
			,m.SubjectEn
			,m.ContentEn
			,m.CreateTime
		FROM dbo.Message m WITH(NOLOCK)
			INNER JOIN dbo.UserMessage um WITH(NOLOCK) ON m.MessageId = um.MessageId
		WHERE m.MessageTypeId = 24 AND um.UserId = @UserId
			AND (
					um.IsRead = 0
					OR um.LastReadTime IS NULL
					OR CONVERT(DATE, um.LastReadTime) <> CONVERT(DATE, @CurrentDateTime)
			)
			AND 1 = CASE m.ReminderTypeId
					WHEN 2 THEN 1 -- Daily
					WHEN 3 THEN CASE WHEN
							',' + REPLACE(REPLACE(CONVERT(VARCHAR(MAX), m.ReminderTypeValue), ';', ','), ' ', ',') + ',' LIKE '%,' + DATENAME(WEEKDAY, @CurrentDateTime) + ',%'
							THEN 1 ELSE 0 END -- Weekly
					WHEN 4 THEN CASE WHEN
							',' + REPLACE(REPLACE(CONVERT(VARCHAR(MAX), m.ReminderTypeValue), ';', ','), ' ', ',') + ',' LIKE '%,' + CONVERT(VARCHAR(5), DATEPART(DAY, @CurrentDateTime)) + ',%'
							OR ('End of month' LIKE '%' + CONVERT(VARCHAR(MAX), m.ReminderTypeValue) + '%'
								AND DATEPART(MONTH, @CurrentDateTime) <> DATEPART(MONTH, DATEADD(DAY, 1, @CurrentDateTime))
							)
							THEN 1 ELSE 0 END -- Monthly
					WHEN 5 THEN CASE WHEN
							',' + REPLACE(REPLACE(CONVERT(VARCHAR(MAX), m.ReminderTypeValue), ';', ','), ' ', ',') + ',' LIKE '%,' + CONVERT(VARCHAR(2), MONTH(@CurrentDateTime)) + '/' + CONVERT(VARCHAR(2), DAY(@CurrentDateTime)) + ',%'
							OR ',' + REPLACE(REPLACE(CONVERT(VARCHAR(MAX), m.ReminderTypeValue), ';', ','), ' ', ',') + ',' LIKE '%,0' + CONVERT(VARCHAR(2), MONTH(@CurrentDateTime)) + '/' + CONVERT(VARCHAR(2), DAY(@CurrentDateTime)) + ',%'
							OR ',' + REPLACE(REPLACE(CONVERT(VARCHAR(MAX), m.ReminderTypeValue), ';', ','), ' ', ',') + ',' LIKE '%,' + CONVERT(VARCHAR(2), MONTH(@CurrentDateTime)) + '/0' + CONVERT(VARCHAR(2), DAY(@CurrentDateTime)) + ',%'
							OR ',' + REPLACE(REPLACE(CONVERT(VARCHAR(MAX), m.ReminderTypeValue), ';', ','), ' ', ',') + ',' LIKE '%,0' + CONVERT(VARCHAR(2), MONTH(@CurrentDateTime)) + '/0' + CONVERT(VARCHAR(2), DAY(@CurrentDateTime)) + ',%'
							THEN 1 ELSE 0 END -- Yearly
					END
		ORDER BY m.CreateTime DESC
	END
	ELSE IF @Top <> 0
	BEGIN
		SELECT TOP (@Top) m.MessageId
			,(SELECT MessageTypeName FROM dbo.MessageType WITH(NOLOCK) WHERE MessageTypeId = m.MessageTypeId) AS MessageTypeName
			,CASE WHEN m.Creator <> 0 THEN (SELECT DisplayName FROM dbo.UserInfo WITH(NOLOCK) WHERE UserId = m.Creator) ELSE 'System' END AS Sender
			,m.SubjectEn
			,m.ContentEn
			,m.CreateTime
		FROM	dbo.Message m WITH(NOLOCK)
			INNER JOIN dbo.UserMessage um WITH(NOLOCK)
				ON	m.MessageId = um.MessageId
		WHERE	(@Mode = 0 and m.MessageTypeId BETWEEN 1 AND 19 -- News - System, News - Manual
					OR (@Mode = 1 AND m.MessageTypeId = 20) -- 1on1
					OR (@Mode = 2 AND m.MessageTypeId BETWEEN 21 AND 39 AND m.MessageTypeId <> 23) -- Important - System, Important - Manual)
					OR (@Mode = 3 AND m.MessageTypeId = 23) -- Private
				)
				AND um.UserId = @UserId
				AND um.IsRead = 0
		ORDER BY m.CreateTime DESC
	END
	ELSE
	BEGIN
		SELECT m.MessageId
			,(SELECT MessageTypeName FROM dbo.MessageType WITH(NOLOCK) WHERE MessageTypeId = m.MessageTypeId) AS MessageTypeName
			,CASE WHEN m.Creator <> 0 THEN (SELECT DisplayName FROM dbo.UserInfo WITH(NOLOCK) WHERE UserId = m.Creator) ELSE 'System' END AS Sender
			,m.SubjectEn
			,m.ContentEn
			,m.CreateTime
		FROM	dbo.Message m WITH(NOLOCK)
			INNER JOIN dbo.UserMessage um WITH(NOLOCK)
				ON	m.MessageId = um.MessageId
		WHERE	(@Mode = 0 and m.MessageTypeId BETWEEN 1 AND 19 -- News - System, News - Manual
					OR (@Mode = 1 AND m.MessageTypeId = 20) -- 1on1
					OR (@Mode = 2 AND m.MessageTypeId BETWEEN 21 AND 39 AND m.MessageTypeId <> 23) -- Important - System, Important - Manual)
					OR (@Mode = 3 AND m.MessageTypeId = 23) -- Private
				)
				AND um.UserId = @UserId
				AND um.IsRead = 0
				AND (@MessageId = 0 OR m.MessageId > @MessageId)
		ORDER BY m.CreateTime DESC
	END
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_InternalNotificationNewestList_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_InternalNotificationNewestList_xtest    Script Date: 2/7/2017 9:24:52 AM ******/

CREATE PROCEDURE [dbo].[OIC_InternalNotificationNewestList_xtest] 
	@UserId		INT
	,@Mode		SMALLINT	= 0
	,@Top		INT			= 10	
	,@MessageId INT			= 0 
AS
/*
	Created by: Kathy
	Date: 20150803
	Task: notification detail [Redmine:#40305]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20161221@Percy: Implement Important - Reminder [RedmineID: #68774]
	
	Param's Explanation:
		@Mode:	0 - News
				1 - 1on1 team
				2 - Important
				3 - Private
				4 - Reminder
		@Top:	0 - ALL
				10 - 10 newest notification
				
		@MessageId:	0 - get all msg at the fist time
					max(messageid) - get more newest msg have id > max(messageid) since last call
		
 */
BEGIN
	SET NOCOUNT ON
	DECLARE @CurrentDateTime DATETIME
	SELECT  @CurrentDateTime = CONVERT(VARCHAR(8), DATEADD(HOUR, 12, GETDATE()), 114) + ' ' + CONVERT(VARCHAR(10), DATEADD(HOUR, 12, GETDATE()), 101) --convert time to GMT +8

	IF @Mode = 4 -- Reminder
	BEGIN
		SELECT m.MessageId
			,(SELECT MessageTypeName FROM dbo.MessageType WITH(NOLOCK) WHERE MessageTypeId = m.MessageTypeId) AS MessageTypeName
			,CASE WHEN m.Creator <> 0 THEN (SELECT DisplayName FROM dbo.UserInfo WITH(NOLOCK) WHERE UserId = m.Creator) ELSE 'System' END AS Sender
			,m.SubjectEn
			,m.ContentEn
			,m.CreateTime
		FROM dbo.Message m WITH(NOLOCK)
			INNER JOIN dbo.UserMessage um WITH(NOLOCK) ON m.MessageId = um.MessageId
		WHERE m.MessageTypeId = 24 AND um.UserId = @UserId
			AND (
					um.IsRead = 0
					OR um.LastReadTime IS NULL
					OR CONVERT(DATE, um.LastReadTime) <> CONVERT(DATE, @CurrentDateTime)
			)
			AND 1 = CASE m.ReminderTypeId
					WHEN 2 THEN 1 -- Daily
					WHEN 3 THEN CASE WHEN
							',' + REPLACE(REPLACE(CONVERT(VARCHAR(MAX), m.ReminderTypeValue), ';', ','), ' ', ',') + ',' LIKE '%,' + DATENAME(WEEKDAY, @CurrentDateTime) + ',%'
							THEN 1 ELSE 0 END -- Weekly
					WHEN 4 THEN CASE WHEN
							',' + REPLACE(REPLACE(CONVERT(VARCHAR(MAX), m.ReminderTypeValue), ';', ','), ' ', ',') + ',' LIKE '%,' + CONVERT(VARCHAR(5), DATEPART(DAY, @CurrentDateTime)) + ',%'
							OR ('End of month' LIKE '%' + CONVERT(VARCHAR(MAX), m.ReminderTypeValue) + '%'
								AND DATEPART(MONTH, @CurrentDateTime) <> DATEPART(MONTH, DATEADD(DAY, 1, @CurrentDateTime))
							)
							THEN 1 ELSE 0 END -- Monthly
					WHEN 5 THEN CASE WHEN
							',' + REPLACE(REPLACE(CONVERT(VARCHAR(MAX), m.ReminderTypeValue), ';', ','), ' ', ',') + ',' LIKE '%,' + CONVERT(VARCHAR(2), MONTH(@CurrentDateTime)) + '/' + CONVERT(VARCHAR(2), DAY(@CurrentDateTime)) + ',%'
							OR ',' + REPLACE(REPLACE(CONVERT(VARCHAR(MAX), m.ReminderTypeValue), ';', ','), ' ', ',') + ',' LIKE '%,0' + CONVERT(VARCHAR(2), MONTH(@CurrentDateTime)) + '/' + CONVERT(VARCHAR(2), DAY(@CurrentDateTime)) + ',%'
							OR ',' + REPLACE(REPLACE(CONVERT(VARCHAR(MAX), m.ReminderTypeValue), ';', ','), ' ', ',') + ',' LIKE '%,' + CONVERT(VARCHAR(2), MONTH(@CurrentDateTime)) + '/0' + CONVERT(VARCHAR(2), DAY(@CurrentDateTime)) + ',%'
							OR ',' + REPLACE(REPLACE(CONVERT(VARCHAR(MAX), m.ReminderTypeValue), ';', ','), ' ', ',') + ',' LIKE '%,0' + CONVERT(VARCHAR(2), MONTH(@CurrentDateTime)) + '/0' + CONVERT(VARCHAR(2), DAY(@CurrentDateTime)) + ',%'
							THEN 1 ELSE 0 END -- Yearly
					END
		ORDER BY m.CreateTime DESC
	END
	ELSE IF @Top <> 0
	BEGIN
		SELECT TOP (@Top) m.MessageId
			,(SELECT MessageTypeName FROM dbo.MessageType WITH(NOLOCK) WHERE MessageTypeId = m.MessageTypeId) AS MessageTypeName
			,CASE WHEN m.Creator <> 0 THEN (SELECT DisplayName FROM dbo.UserInfo WITH(NOLOCK) WHERE UserId = m.Creator) ELSE 'System' END AS Sender
			,m.SubjectEn
			,m.ContentEn
			,m.CreateTime
		FROM	dbo.Message m WITH(NOLOCK)
			INNER JOIN dbo.UserMessage um WITH(NOLOCK)
				ON	m.MessageId = um.MessageId
		WHERE	(@Mode = 0 and m.MessageTypeId BETWEEN 1 AND 19 -- News - System, News - Manual
					OR (@Mode = 1 AND m.MessageTypeId = 20) -- 1on1
					OR (@Mode = 2 AND m.MessageTypeId BETWEEN 21 AND 39 AND m.MessageTypeId <> 23) -- Important - System, Important - Manual)
					OR (@Mode = 3 AND m.MessageTypeId = 23) -- Private
				)
				AND um.UserId = @UserId
				AND um.IsRead = 0
		ORDER BY m.CreateTime DESC
	END
	ELSE
	BEGIN
		SELECT m.MessageId
			,(SELECT MessageTypeName FROM dbo.MessageType WITH(NOLOCK) WHERE MessageTypeId = m.MessageTypeId) AS MessageTypeName
			,CASE WHEN m.Creator <> 0 THEN (SELECT DisplayName FROM dbo.UserInfo WITH(NOLOCK) WHERE UserId = m.Creator) ELSE 'System' END AS Sender
			,m.SubjectEn
			,m.ContentEn
			,m.CreateTime
		FROM	dbo.Message m WITH(NOLOCK)
			INNER JOIN dbo.UserMessage um WITH(NOLOCK)
				ON	m.MessageId = um.MessageId
		WHERE	(@Mode = 0 and m.MessageTypeId BETWEEN 1 AND 19 -- News - System, News - Manual
					OR (@Mode = 1 AND m.MessageTypeId = 20) -- 1on1
					OR (@Mode = 2 AND m.MessageTypeId BETWEEN 21 AND 39 AND m.MessageTypeId <> 23) -- Important - System, Important - Manual)
					OR (@Mode = 3 AND m.MessageTypeId = 23) -- Private
				)
				AND um.UserId = @UserId
				AND um.IsRead = 0
				AND (@MessageId = 0 OR m.MessageId > @MessageId)
		ORDER BY m.CreateTime DESC
	END
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_InternalNotificationNumberGet]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_InternalNotificationNumberGet    Script Date: 26/08/2015 12:33:24 PM ******/
CREATE PROCEDURE [dbo].[OIC_InternalNotificationNumberGet] 
	@UserId			INT
	,@News			INT = 0 OUTPUT
	,@CSD			INT = 0 OUTPUT
	,@Important		INT = 0 OUTPUT
	,@Private		INT = 0 OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150803
	Task: Get total of internal notification [Redmine:#40305]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	Param's Explanation:
		
 */
BEGIN
	SET NOCOUNT ON
	
	SELECT	@News = SUM(CASE WHEN m.MessageTypeId BETWEEN 1 AND 19 THEN 1 ELSE 0 END)
			,@CSD = SUM(CASE WHEN m.MessageTypeId = 20 THEN 1 ELSE 0 END)
			,@Important = SUM(CASE WHEN m.MessageTypeId BETWEEN 21 AND 39 AND m.MessageTypeId <> 23 THEN 1 ELSE 0 END)
			,@Private = SUM(CASE WHEN m.MessageTypeId = 23 THEN 1 ELSE 0 END) 
	FROM dbo.UserMessage um WITH(NOLOCK)
		INNER JOIN dbo.Message m WITH(NOLOCK) 
			ON	um.MessageId = m.MessageId
	WHERE	UserId = @UserId
			AND um.IsRead = 0
			AND m.MessageTypeId BETWEEN 1 AND 39
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_InternalNotificationSenderSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_InternalNotificationSenderSel    Script Date: 17/09/2015 5:13:34 PM ******/
/****** Object:  Stored Procedure dbo.OIC_InternalNotificationSenderSel    Script Date: 28/08/2015 4:12:39 PM ******/
CREATE PROCEDURE [dbo].[OIC_InternalNotificationSenderSel] 
	@Mode	INT		= 0 -- All
AS
/*
	Created by: Kathy
	Date: 20150730
	Task: get all position & sender belong to [Redmine:#40305]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		
	Param's Explanation:
		@Mode : 0 - All
				1 - exclude system
				
 */
BEGIN
	SET NOCOUNT ON

	SELECT	0 AS UserId
			,NULL AS DisplayName
			,0 AS PositionId
			,'System' AS PositionName
	WHERE	@Mode = 0
	UNION ALL
	SELECT  u.UserId 
			,u.DisplayName
			,p.PositionId
			,p.PositionName
	FROM	dbo.Position p WITH(NOLOCK)
		INNER JOIN dbo.UserInfo u WITH(NOLOCK)
		ON	p.PositionId = u.PositionId
	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_InternalNotificationStatusUpd]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_InternalNotificationStatusUpd    Script Date: 2/9/2017 3:10:45 AM ******/
/****** Object:  Stored Procedure dbo.OIC_InternalNotificationStatusUpd    Script Date: 2/7/2017 9:24:52 AM ******/

CREATE PROCEDURE [dbo].[OIC_InternalNotificationStatusUpd]
	@SelectedMessage	VARCHAR(MAX)
	,@IsRead			BIT				= 1
	
	,@UserId			INT
	,@Language			VARCHAR(10)		= 'E'
	,@IP				VARCHAR(50)		= NULL
	,@ErrCode			INT				= 0			OUTPUT
	,@ErrMsg			VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150731
	Task: update notification status [Redmine:#40305]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20161223@Percy: Update Last Time Read of Reminder Message [RedmineID: #68774]
	
	Param's Explanation:
	
 */
BEGIN
	SET NOCOUNT ON
	DECLARE @startRun		DATETIME
			,@endRun		DATETIME
			,@duration		INT
			,@logSPOlddata	NVARCHAR(MAX)
			,@logSPData		NVARCHAR(MAX)
			,@xml			XML
			,@procName		VARCHAR(200)
			,@LastReadTime	DATETIME
			
	CREATE TABLE #tblMessage (MessageId INT)
	
	SELECT	@startRun = GETDATE()
	SELECT  @LastReadTime = CONVERT(VARCHAR(8), DATEADD(HOUR, 12, GETDATE()), 114) + ' ' + CONVERT(VARCHAR(10), DATEADD(HOUR, 12, GETDATE()), 101)
	
	INSERT INTO #tblMessage (MessageId)
	SELECT	val
	FROM	dbo.strSplit(@SelectedMessage, ',')
	
	BEGIN TRY
		UPDATE	um
			SET	IsRead = @IsRead,
				LastReadTime = CASE WHEN m.MessageTypeId = 24 THEN @LastReadTime ELSE NULL END
		FROM	dbo.UserMessage um WITH(ROWLOCK, UPDLOCK)
			INNER JOIN dbo.Message m WITH(NOLOCK) ON um.MessageId = m.MessageId
		WHERE	UserId = @UserId
				AND EXISTS (SELECT MessageId FROM #tblMessage tm WHERE um.MessageId = tm.MessageId)
	END TRY
	BEGIN CATCH
		SELECT	@Errcode = 100
				,@ErrMsg = dbo.f_Get_MsgNamebyMsgID(40001, @Language)
		RETURN
	END CATCH			
	
	-- write log
	SET @xml = (
		SELECT	@SelectedMessage	AS '@sm'
				,@IsRead			AS '@ir'
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT	@logSPData		= CONVERT(NVARCHAR(MAX), @xml)

	SELECT @IsRead = ~ @IsRead

	SET @xml = (
		SELECT	@SelectedMessage	AS '@sm'
				,@IsRead			AS '@ir'
		FOR XML PATH('r'), TYPE
		)
	
	SELECT	@logSPOlddata	= CONVERT(NVARCHAR(MAX), @xml)
			,@endRun		= GETDATE()  
			,@duration		= DATEDIFF(MILLISECOND, @startRun, @endRun)   
			,@procName		= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOlddata
		,@Duration		= @Duration	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_InternalNotificationStatusUpd_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_InternalNotificationStatusUpd_xtest    Script Date: 2/7/2017 9:24:52 AM ******/

CREATE PROCEDURE [dbo].[OIC_InternalNotificationStatusUpd_xtest]
	@SelectedMessage	VARCHAR(MAX)
	,@IsRead			BIT				= 1
	
	,@UserId			INT
	,@Language			VARCHAR(10)		= 'E'
	,@IP				VARCHAR(50)		= NULL
	,@ErrCode			INT				= 0			OUTPUT
	,@ErrMsg			VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150731
	Task: update notification status [Redmine:#40305]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20161223@Percy: Update Last Time Read of Reminder Message [RedmineID: #68774]
	
	Param's Explanation:
	
 */
BEGIN
	SET NOCOUNT ON
	DECLARE @startRun		DATETIME
			,@endRun		DATETIME
			,@duration		INT
			,@logSPOlddata	NVARCHAR(MAX)
			,@logSPData		NVARCHAR(MAX)
			,@xml			XML
			,@procName		VARCHAR(200)
			,@LastReadTime	DATETIME
			
	CREATE TABLE #tblMessage (MessageId INT)
	
	SELECT	@startRun = GETDATE()
	SELECT  @LastReadTime = CONVERT(VARCHAR(8), DATEADD(HOUR, 12, GETDATE()), 114) + ' ' + CONVERT(VARCHAR(10), DATEADD(HOUR, 12, GETDATE()), 101)
	
	INSERT INTO #tblMessage (MessageId)
	SELECT	val
	FROM	dbo.strSplit(@SelectedMessage, ',')
	
	BEGIN TRY
		UPDATE	um
			SET	IsRead = @IsRead,
				LastReadTime = CASE WHEN m.MessageTypeId = 24 THEN @LastReadTime ELSE NULL END
		FROM	dbo.UserMessage um WITH(ROWLOCK, UPDLOCK)
			INNER JOIN dbo.Message m WITH(NOLOCK) ON um.MessageId = m.MessageId
		WHERE	UserId = @UserId
				AND EXISTS (SELECT MessageId FROM #tblMessage tm WHERE um.MessageId = tm.MessageId)
	END TRY
	BEGIN CATCH
		SELECT	@Errcode = 100
				,@ErrMsg = dbo.f_Get_MsgNamebyMsgID(40001, @Language)
		RETURN
	END CATCH			
	
	-- write log
	SET @xml = (
		SELECT	@SelectedMessage	AS '@sm'
				,@IsRead			AS '@ir'
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT	@logSPData		= CONVERT(NVARCHAR(MAX), @xml)

	SELECT @IsRead = ~ @IsRead

	SET @xml = (
		SELECT	@SelectedMessage	AS '@sm'
				,@IsRead			AS '@ir'
		FOR XML PATH('r'), TYPE
		)
	
	SELECT	@logSPOlddata	= CONVERT(NVARCHAR(MAX), @xml)
			,@endRun		= GETDATE()  
			,@duration		= DATEDIFF(MILLISECOND, @startRun, @endRun)   
			,@procName		= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOlddata
		,@Duration		= @Duration	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LanguageSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LanguageSel    Script Date: 9/12/2016 11:46:48 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LanguageSel    Script Date: 8/26/2016 3:35:35 PM ******/

CREATE PROCEDURE [dbo].[OIC_LanguageSel]
AS

/*
	Created by: Dom
	Date: 2014-12-18
	Task: Get language list [Redmine:#27752]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160826@Percy: Remove Other Language (ID = 4) [RedmineID: #62883]
		
 */

BEGIN
	SET NOCOUNT ON
	SELECT LanguageId
		,LanguageName 
	FROM dbo.[Language] WITH(NOLOCK)
	WHERE LanguageId <> 4
	ORDER BY LanguageName
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LanguageSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LanguageSel_xtest    Script Date: 8/26/2016 3:35:35 PM ******/

CREATE PROCEDURE [dbo].[OIC_LanguageSel_xtest]
AS

/*
	Created by: Dom
	Date: 2014-12-18
	Task: Get language list [Redmine:#27752]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160826@Percy: Remove Other Language (ID = 4) [RedmineID: #62883]
		
 */

BEGIN
	SET NOCOUNT ON
	SELECT LanguageId
		,LanguageName 
	FROM dbo.[Language] WITH(NOLOCK)
	WHERE LanguageId <> 4
	ORDER BY LanguageName
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeCategoryDel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeCategoryDel    Script Date: 11/21/2016 10:54:29 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeCategoryDel    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeCategoryDel] 
	@SelectedCategory	VARCHAR(500)
	,@SelectedLicensee	VARCHAR(500)
	
	,@UserId			INT
	,@Language			VARCHAR(10)		= 'E'
	,@IP				VARCHAR(50)		= NULL
	,@ErrCode			INT				= 0			OUTPUT
	,@ErrMsg			VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Creator: Percy
	Date: 2016-09-28
	DB: DBOIC.bodb_OIC
	Task: Insert Category of Licensee
	Remark: Parent SP: OIC_LicenseeCategoryManage @ActionID = 0 -- Remove

	Revisions:

	Param's Explanation:
		*@SelectedLicensee: '1,2,3,4'
		*@SelectedCategory: '1,2,3,4'
*/
BEGIN
	SET NOCOUNT ON

	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPOldData	NVARCHAR(MAX)
		,@procName		VARCHAR(200)

		,@tempStartRun	DATETIME
		,@tempEndRun	DATETIME
	
	SET @startRun = GETDATE()

	DECLARE @xml XML -- write old data before remove

	DECLARE @tblLicenseeCategoryAssigned TABLE (LicenseeId INT, CategoryId TINYINT)
	INSERT INTO @tblLicenseeCategoryAssigned (LicenseeId, CategoryId)
	SELECT LicenseeId, CONVERT(INT, s.val) AS CategoryId
	FROM (
		SELECT CONVERT(INT, val) AS LicenseeId
		FROM dbo.strSplit(@SelectedLicensee, ',')
	) t
		CROSS APPLY dbo.strSplit(@SelectedCategory,',') s
		
	----Validate input param:
	DELETE	t
	FROM @tblLicenseeCategoryAssigned t
	WHERE t.LicenseeId NOT IN (SELECT l.LicenseeId
								FROM dbo.LicenseeCategoryAssigned l WITH(NOLOCK) 
								WHERE l.CategoryId = t.CategoryId
							)
		
	IF NOT EXISTS(SELECT TOP 1 1 FROM @tblLicenseeCategoryAssigned)
	BEGIN
		SELECT @ErrCode = 104
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1505, @Language) -- Cannot retract selected categories from clients because all of them do not have these categories.
		RETURN
	END
		
	BEGIN TRY
		DELETE lc
		FROM dbo.LicenseeCategoryAssigned lc
		WHERE lc.LicenseeId IN (SELECT t.LicenseeId
								FROM @tblLicenseeCategoryAssigned t 
								WHERE t.CategoryId = lc.CategoryId
							)
								
		-- Remove contacts have been assigned by Category
		DELETE cc
		FROM dbo.CategoryContact cc
			INNER JOIN dbo.Contact c WITH(NOLOCK) 
				ON c.ContactID = cc.ContactID 
					AND c.LicenseeID IN (SELECT LicenseeId FROM @tblLicenseeCategoryAssigned)
					AND cc.CategoryID IN (SELECT CategoryId FROM @tblLicenseeCategoryAssigned)
			
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 102
			,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1501, @Language) -- Fail to dissociate category(ies). Please try again.
		RETURN
	END CATCH

	SELECT  @procName = OBJECT_NAME(@@PROCID)
			,@tempEndRun = GETDATE()
				
	DECLARE @LicenseeCategory TABLE (LicenseeId INT, CategoryId TINYINT)
	DECLARE @LicenseeId INT

	WHILE 1=1
	BEGIN
		SELECT @tempStartRun = GETDATE(), @LicenseeId = NULL
		DELETE @LicenseeCategory

		SELECT TOP 1 @LicenseeId = LicenseeId FROM @tblLicenseeCategoryAssigned
		IF @LicenseeId IS NULL
			BREAK

		DELETE @tblLicenseeCategoryAssigned OUTPUT DELETED.LicenseeId, DELETED.CategoryId INTO @LicenseeCategory WHERE LicenseeId = @LicenseeId

		SET @xml = (SELECT	l.LicenseeId	AS '@lid'
							,l.LicenseeName AS '@ln'
							,(SELECT c.CategoryId		AS '@cid'
									,c.CategoryName		AS '@cn'
								FROM dbo.Category c WITH(NOLOCK)
									INNER JOIN @LicenseeCategory lc ON c.CategoryId = lc.CategoryId
								FOR XML PATH('row'), ROOT('c'), TYPE
							)
					FROM dbo.Licensee l WITH(NOLOCK)
					WHERE l.LicenseeId = @LicenseeId
					FOR XML PATH('r'), TYPE
					)
		SELECT @logSPOldData = CONVERT(NVARCHAR(MAX), @xml)

		SELECT	@endRun		= GETDATE()  
				,@duration	= DATEDIFF(MILLISECOND, @startRun, @tempEndRun) + DATEDIFF(MILLISECOND, @tempStartRun, @endRun)

				EXEC dbo.OIC_LogRunSpIns
			@UserId			= @UserId
			,@SPName		= @procName
			,@Language		= @Language
			,@IP			= @IP
			,@Data			= NULL
			,@OldData		= @logSPOldData
			,@Duration		= @Duration
	END
END

GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeCategoryDel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeCategoryDel_xtest    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeCategoryDel_xtest] 
	@SelectedCategory	VARCHAR(500)
	,@SelectedLicensee	VARCHAR(500)
	
	,@UserId			INT
	,@Language			VARCHAR(10)		= 'E'
	,@IP				VARCHAR(50)		= NULL
	,@ErrCode			INT				= 0			OUTPUT
	,@ErrMsg			VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Creator: Percy
	Date: 2016-09-28
	DB: DBOIC.bodb_OIC
	Task: Insert Category of Licensee
	Remark: Parent SP: OIC_LicenseeCategoryManage_xtest @ActionID = 0 -- Remove

	Revisions:

	Param's Explanation:
		*@SelectedLicensee: '1,2,3,4'
		*@SelectedCategory: '1,2,3,4'
*/
BEGIN
	SET NOCOUNT ON

	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPOldData	NVARCHAR(MAX)
		,@procName		VARCHAR(200)

		,@tempStartRun	DATETIME
		,@tempEndRun	DATETIME
	
	SET @startRun = GETDATE()

	DECLARE @xml XML -- write old data before remove

	DECLARE @tblLicenseeCategoryAssigned TABLE (LicenseeId INT, CategoryId TINYINT)
	INSERT INTO @tblLicenseeCategoryAssigned (LicenseeId, CategoryId)
	SELECT LicenseeId, CONVERT(INT, s.val) AS CategoryId
	FROM (
		SELECT CONVERT(INT, val) AS LicenseeId
		FROM dbo.strSplit(@SelectedLicensee, ',')
	) t
		CROSS APPLY dbo.strSplit(@SelectedCategory,',') s
		
	----Validate input param:
	DELETE	t
	FROM @tblLicenseeCategoryAssigned t
	WHERE t.LicenseeId NOT IN (SELECT l.LicenseeId
								FROM dbo.LicenseeCategoryAssigned l WITH(NOLOCK) 
								WHERE l.CategoryId = t.CategoryId
							)
		
	IF NOT EXISTS(SELECT TOP 1 1 FROM @tblLicenseeCategoryAssigned)
	BEGIN
		SELECT @ErrCode = 104
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1505, @Language) -- Cannot retract selected categories from clients because all of them do not have these categories.
		RETURN
	END
		
	BEGIN TRY
		DELETE lc
		FROM dbo.LicenseeCategoryAssigned lc
		WHERE lc.LicenseeId IN (SELECT t.LicenseeId
								FROM @tblLicenseeCategoryAssigned t 
								WHERE t.CategoryId = lc.CategoryId
							)
								
		-- Remove contacts have been assigned by Category
		DELETE cc
		FROM dbo.CategoryContact cc
			INNER JOIN dbo.Contact c WITH(NOLOCK) 
				ON c.ContactID = cc.ContactID 
					AND c.LicenseeID IN (SELECT LicenseeId FROM @tblLicenseeCategoryAssigned)
					AND cc.CategoryID IN (SELECT CategoryId FROM @tblLicenseeCategoryAssigned)
			
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 102
			,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1501, @Language) -- Fail to dissociate category(ies). Please try again.
		RETURN
	END CATCH

	SELECT  @procName = OBJECT_NAME(@@PROCID)
			,@tempEndRun = GETDATE()
				
	DECLARE @LicenseeCategory TABLE (LicenseeId INT, CategoryId TINYINT)
	DECLARE @LicenseeId INT

	WHILE 1=1
	BEGIN
		SELECT @tempStartRun = GETDATE(), @LicenseeId = NULL
		DELETE @LicenseeCategory

		SELECT TOP 1 @LicenseeId = LicenseeId FROM @tblLicenseeCategoryAssigned
		IF @LicenseeId IS NULL
			BREAK

		DELETE @tblLicenseeCategoryAssigned OUTPUT DELETED.LicenseeId, DELETED.CategoryId INTO @LicenseeCategory WHERE LicenseeId = @LicenseeId

		SET @xml = (SELECT	l.LicenseeId	AS '@lid'
							,l.LicenseeName AS '@ln'
							,(SELECT c.CategoryId		AS '@cid'
									,c.CategoryName		AS '@cn'
								FROM dbo.Category c WITH(NOLOCK)
									INNER JOIN @LicenseeCategory lc ON c.CategoryId = lc.CategoryId
								FOR XML PATH('row'), ROOT('c'), TYPE
							)
					FROM dbo.Licensee l WITH(NOLOCK)
					WHERE l.LicenseeId = @LicenseeId
					FOR XML PATH('r'), TYPE
					)
		SELECT @logSPOldData = CONVERT(NVARCHAR(MAX), @xml)

		SELECT	@endRun		= GETDATE()  
				,@duration	= DATEDIFF(MILLISECOND, @startRun, @tempEndRun) + DATEDIFF(MILLISECOND, @tempStartRun, @endRun)

		EXEC dbo.OIC_LogRunSpIns_xtest
			@UserId			= @UserId
			,@SPName		= @procName
			,@Language		= @Language
			,@IP			= @IP
			,@Data			= NULL
			,@OldData		= @logSPOldData
			,@Duration		= @Duration
	END
END
GRANT EXECUTE ON [dbo].[OIC_LicenseeCategoryDel_xtest] TO [bodbAdminNet] AS [dbo]
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeCategoryIns]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeCategoryIns    Script Date: 11/21/2016 10:54:28 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeCategoryIns    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeCategoryIns] 
	@SelectedCategory	VARCHAR(500)
	,@SelectedLicensee	VARCHAR(500)
	
	,@UserId			INT
	,@Language			VARCHAR(10)		= 'E'
	,@IP				VARCHAR(50)		= NULL
	,@ErrCode			INT				= 0			OUTPUT
	,@ErrMsg			VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Creator: Percy
	Date: 2016-09-28
	DB: DBOIC.bodb_OIC
	Task: Insert Category of Licensee
	Remark: Parent SP: OIC_LicenseeCategoryManage @ActionID = 1 -- Add

	Revisions:

	Param's Explanation:
		*@SelectedLicensee: '1,2,3,4'
		*@SelectedCategory: '1,2,3,4'
*/
BEGIN
	SET NOCOUNT ON

	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@procName		VARCHAR(200)

		,@tempStartRun	DATETIME
		,@tempEndRun	DATETIME
	
	SET @startRun = GETDATE()

	DECLARE @xml XML -- write log

	DECLARE @tblLicenseeCategoryAssigned TABLE(LicenseeId INT, CategoryId TINYINT)
	INSERT INTO @tblLicenseeCategoryAssigned (LicenseeId, CategoryId)
	SELECT LicenseeId, CONVERT(INT, s.val) AS CategoryId
	FROM (
		SELECT CONVERT(INT, val) AS LicenseeId FROM dbo.strSplit(@SelectedLicensee, ',')
	) t
		CROSS APPLY dbo.strSplit(@SelectedCategory,',') s

	DELETE t
	FROM @tblLicenseeCategoryAssigned t
		INNER JOIN LicenseeCategoryAssigned lc WITH(NOLOCK) ON lc.LicenseeId = t.LicenseeId AND lc.CategoryId = t.CategoryId
		
	IF NOT EXISTS(SELECT TOP 1 1 FROM @tblLicenseeCategoryAssigned)
	BEGIN
		SELECT	@ErrCode = 103
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1504, @Language) -- Cannot assign selected categories to clients because all of them already have these categories.
		RETURN
	END
		
	BEGIN TRY		
		INSERT INTO dbo.LicenseeCategoryAssigned (LicenseeId, CategoryId)
		SELECT LicenseeId ,CategoryId
		FROM @tblLicenseeCategoryAssigned
			
		--  Assign the categories to the client main's contact (Cc)
		INSERT INTO dbo.CategoryContact (ContactID, CategoryID, RecipientType)
		SELECT c.ContactID, t.CategoryId, 1 -- Cc
		FROM dbo.Contact c WITH(NOLOCK)
			INNER JOIN @tblLicenseeCategoryAssigned t ON c.LicenseeID = t.LicenseeId AND c.IsMain = 1
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1500, @Language) -- Fail to assign category(ies). Please try again
		RETURN
	END CATCH

	-- write log
	DECLARE @LicenseeCategory TABLE (LicenseeId INT, CategoryId TINYINT)
	DECLARE @LicenseeId INT

	SELECT  @procName = OBJECT_NAME(@@PROCID)
			,@tempEndRun = GETDATE()

	WHILE 1=1
	BEGIN
		SELECT @tempStartRun = GETDATE(), @LicenseeId = NULL
		DELETE @LicenseeCategory

		SELECT TOP 1 @LicenseeId = LicenseeId FROM @tblLicenseeCategoryAssigned
		IF @LicenseeId IS NULL
			BREAK

		DELETE @tblLicenseeCategoryAssigned OUTPUT DELETED.LicenseeId, DELETED.CategoryId INTO @LicenseeCategory WHERE LicenseeId = @LicenseeId

		SET @xml = (SELECT	l.LicenseeId	AS '@lid'
							,l.LicenseeName AS '@ln'
							,(SELECT c.CategoryId		AS '@cid'
									,c.CategoryName		AS '@cn'
								FROM dbo.Category c WITH(NOLOCK)
									INNER JOIN @LicenseeCategory lc ON c.CategoryId = lc.CategoryId
								FOR XML PATH('row'), ROOT('c'), TYPE
							)
					FROM dbo.Licensee l WITH(NOLOCK)
					WHERE l.LicenseeId = @LicenseeId
					FOR XML PATH('r'), TYPE
					)
		SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)

		SELECT	@endRun		= GETDATE()  
				,@duration	= DATEDIFF(MILLISECOND, @startRun, @tempEndRun) + DATEDIFF(MILLISECOND, @tempStartRun, @endRun)

				EXEC dbo.OIC_LogRunSpIns
			@UserId			= @UserId
			,@SPName		= @procName
			,@Language		= @Language
			,@IP			= @IP
			,@Data			= @logSPData
			,@OldData		= NULL
			,@Duration		= @Duration
	END
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeCategoryIns_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeCategoryIns_xtest    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeCategoryIns_xtest] 
	@SelectedCategory	VARCHAR(500)
	,@SelectedLicensee	VARCHAR(500)
	
	,@UserId			INT
	,@Language			VARCHAR(10)		= 'E'
	,@IP				VARCHAR(50)		= NULL
	,@ErrCode			INT				= 0			OUTPUT
	,@ErrMsg			VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Creator: Percy
	Date: 2016-09-28
	DB: DBOIC.bodb_OIC
	Task: Insert Category of Licensee
	Remark: Parent SP: OIC_LicenseeCategoryManage_xtest @ActionID = 1 -- Add

	Revisions:

	Param's Explanation:
		*@SelectedLicensee: '1,2,3,4'
		*@SelectedCategory: '1,2,3,4'
*/
BEGIN
	SET NOCOUNT ON

	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@procName		VARCHAR(200)

		,@tempStartRun	DATETIME
		,@tempEndRun	DATETIME
	
	SET @startRun = GETDATE()

	DECLARE @xml XML -- write log

	DECLARE @tblLicenseeCategoryAssigned TABLE(LicenseeId INT, CategoryId TINYINT)
	INSERT INTO @tblLicenseeCategoryAssigned (LicenseeId, CategoryId)
	SELECT LicenseeId, CONVERT(INT, s.val) AS CategoryId
	FROM (
		SELECT CONVERT(INT, val) AS LicenseeId FROM dbo.strSplit(@SelectedLicensee, ',')
	) t
		CROSS APPLY dbo.strSplit(@SelectedCategory,',') s

	DELETE t
	FROM @tblLicenseeCategoryAssigned t
		INNER JOIN LicenseeCategoryAssigned lc WITH(NOLOCK) ON lc.LicenseeId = t.LicenseeId AND lc.CategoryId = t.CategoryId
		
	IF NOT EXISTS(SELECT TOP 1 1 FROM @tblLicenseeCategoryAssigned)
	BEGIN
		SELECT	@ErrCode = 103
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1504, @Language) -- Cannot assign selected categories to clients because all of them already have these categories.
		RETURN
	END
		
	BEGIN TRY		
		INSERT INTO dbo.LicenseeCategoryAssigned (LicenseeId, CategoryId)
		SELECT LicenseeId ,CategoryId
		FROM @tblLicenseeCategoryAssigned
			
		--  Assign the categories to the client main's contact (Cc)
		INSERT INTO dbo.CategoryContact (ContactID, CategoryID, RecipientType)
		SELECT c.ContactID, t.CategoryId, 1 -- Cc
		FROM dbo.Contact c WITH(NOLOCK)
			INNER JOIN @tblLicenseeCategoryAssigned t ON c.LicenseeID = t.LicenseeId AND c.IsMain = 1
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1500, @Language) -- Fail to assign category(ies). Please try again
		RETURN
	END CATCH

	-- write log
	DECLARE @LicenseeCategory TABLE (LicenseeId INT, CategoryId TINYINT)
	DECLARE @LicenseeId INT

	SELECT  @procName = OBJECT_NAME(@@PROCID)
			,@tempEndRun = GETDATE()

	WHILE 1=1
	BEGIN
		SELECT @tempStartRun = GETDATE(), @LicenseeId = NULL
		DELETE @LicenseeCategory

		SELECT TOP 1 @LicenseeId = LicenseeId FROM @tblLicenseeCategoryAssigned
		IF @LicenseeId IS NULL
			BREAK

		DELETE @tblLicenseeCategoryAssigned OUTPUT DELETED.LicenseeId, DELETED.CategoryId INTO @LicenseeCategory WHERE LicenseeId = @LicenseeId

		SET @xml = (SELECT	l.LicenseeId	AS '@lid'
							,l.LicenseeName AS '@ln'
							,(SELECT c.CategoryId		AS '@cid'
									,c.CategoryName		AS '@cn'
								FROM dbo.Category c WITH(NOLOCK)
									INNER JOIN @LicenseeCategory lc ON c.CategoryId = lc.CategoryId
								FOR XML PATH('row'), ROOT('c'), TYPE
							)
					FROM dbo.Licensee l WITH(NOLOCK)
					WHERE l.LicenseeId = @LicenseeId
					FOR XML PATH('r'), TYPE
					)
		SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)

		SELECT	@endRun		= GETDATE()  
				,@duration	= DATEDIFF(MILLISECOND, @startRun, @tempEndRun) + DATEDIFF(MILLISECOND, @tempStartRun, @endRun)

		EXEC dbo.OIC_LogRunSpIns_xtest
			@UserId			= @UserId
			,@SPName		= @procName
			,@Language		= @Language
			,@IP			= @IP
			,@Data			= @logSPData
			,@OldData		= NULL
			,@Duration		= @Duration
	END
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeCategoryListSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeCategoryListSel    Script Date: 9/11/2017 11:37:05 PM ******/
CREATE PROCEDURE [dbo].[OIC_LicenseeCategoryListSel]   
	@UserId					INT  
	,@SelectedLicenseeType	VARCHAR(50)	= 'All'
	,@LicenseeName			NVARCHAR(50) = '%'  
	,@StatusIds				VARCHAR(50)	= 'All'
	,@SelectedCategory		VARCHAR(500) = 'All'  
   
	,@PageSize				INT = 10  
	,@PageIndex				INT = 0  
	,@TotalRecords			INT = 0 OUTPUT  
AS  
/*  
	Created by: Kathy  
	Date: 2015-03-31  
	Task: Licensee category mailing list [Redmine:#29611]  
	DB: DBOIC.bodb_OIC  
   
	Revisions:  
		- 20160818@Percy: Return new column: CategoryNameCN -- Add Chinese name [RedmineID: #62642]
		- 20161214@Percy: Change dropdown TOL filter multiple choices [RedmineID: #68774]
		- 20170828@Scofield: Update LicenseeStatusIds [#82144]
   
	Param's Explanation:  
		@SelectedCategory: support multiple selection  
		@PageIndex: 0 - the first page  
    
 */  
BEGIN  
 
	SET NOCOUNT ON  
   
	DECLARE @RowCount INT   
		,@RowStart INT  
		,@RowEnd INT  
     
	SELECT @PageIndex = @PageIndex ,  
		@RowStart = @PageSize * @PageIndex + 1  
		,@RowEnd = @RowStart + @PageSize - 1  
     
	DECLARE @tblCategory     TABLE (CategoryId TINYINT, CategoryName VARCHAR(100), CategoryNameCN NVARCHAR(200))         
	DECLARE @tblLicenseeCategoryAssigned TABLE (LicenseeId INT)  
	DECLARE @tblLicenseeType    TABLE (LicenseeTypeId TINYINT)  
	CREATE TABLE #tblResult (  
		RowNumber		INT  
		,LicenseeId		INT  
		,LicenseeName	NVARCHAR(50)  
		,StatusName		VARCHAR(30)  
		,TypeName		VARCHAR(30)  
	)  
   
	INSERT INTO @tblCategory (CategoryId, CategoryName, CategoryNameCN)  
	SELECT CategoryId, CategoryName, CategoryNameCN  
	FROM dbo.Category   
	WHERE
		@SelectedCategory = 'All'  
		OR CategoryId IN (SELECT val FROM dbo.strSplit(@SelectedCategory,',' ))  
   
	INSERT INTO @tblLicenseeCategoryAssigned (LicenseeId)        
	SELECT lc.LicenseeId  
	FROM dbo.LicenseeCategoryAssigned lc WITH(NOLOCK)  
		INNER JOIN @tblCategory c   
			ON lc.CategoryId = c.CategoryId  
	GROUP BY lc.LicenseeId  
	HAVING COUNT(DISTINCT lc.CategoryId) = CASE WHEN @SelectedCategory = 'All' THEN COUNT(DISTINCT lc.CategoryId) ELSE (SELECT COUNT(1) FROM @tblCategory) END           
            
	IF @SelectedLicenseeType = 'All'
	BEGIN
		INSERT INTO @tblLicenseeType (LicenseeTypeId)
		SELECT	LicenseeTypeId
		FROM	dbo.UserLicenseeType WITH(NOLOCK)
		WHERE	UserId = @UserId
	END
	ELSE
	BEGIN
		INSERT INTO @tblLicenseeType (LicenseeTypeId)
		SELECT CONVERT(TINYINT, val) FROM dbo.strSplit(@SelectedLicenseeType, ',')

		DELETE lt
		FROM @tblLicenseeType lt
			LEFT JOIN dbo.UserLicenseeType ult WITH(NOLOCK) ON lt.LicenseeTypeId = ult.LicenseeTypeId AND ult.UserId = @UserId
		WHERE ult.LicenseeTypeId IS NULL
	END
     
	INSERT INTO #tblResult(  
		RowNumber  
		,LicenseeId  
		,LicenseeName  
		,StatusName  
		,TypeName  
	)       
	SELECT ROW_NUMBER() OVER(ORDER BY l.LicenseeName) AS RowNumber  
		,l.LicenseeId  
		,l.LicenseeName  
		,ls.LicenseeStatusName  
		,lt.LicenseeTypeName  
	FROM dbo.Licensee l WITH(NOLOCK)  
		INNER JOIN dbo.LicenseeStatus ls WITH(NOLOCK)   
			ON l.LicenseeStatusId = ls.LicenseeStatusId  
		INNER JOIN dbo.LicenseeType lt WITH(NOLOCK)   
			ON l.LicenseeTypeId = lt.LicenseeTypeId  
	WHERE l.LicenseeTypeId IN (SELECT LicenseeTypeId FROM @tblLicenseeType)  
		AND (@StatusIds = 'All' OR ls.LicenseeStatusId IN (SELECT val FROM dbo.strSplit(@StatusIds,',')))  
		AND l.LicenseeName LIKE @LicenseeName + '%'  
		AND l.LicenseeId IN (SELECT LicenseeId FROM @tblLicenseeCategoryAssigned)  
      
	IF @TotalRecords = 0  
	BEGIN  
		SELECT @TotalRecords = COUNT(1)  
		FROM #tblResult  
	END   
   
	SELECT LicenseeId  
		,LicenseeName  
		,StatusName  
		,TypeName  
	FROM #tblResult  
	WHERE RowNumber BETWEEN @RowStart AND @RowEnd  
   
	SELECT t.LicenseeId  
		,lc.CategoryId  
		,c.CategoryName
		,c.CategoryNameCN
		,(SELECT c.ContactEmail  
				,c.ContactName  
				,c.IsMain  
			FROM dbo.CategoryContact cc WITH(NOLOCK)  
				INNER JOIN dbo.Contact c WITH(NOLOCK)   
					ON c.ContactID = cc.ContactID   
						AND cc.RecipientType = 0   
						AND cc.CategoryID = lc.CategoryId   
						AND c.LicenseeID = t.LicenseeId  
			FOR XML RAW('row'), ROOT('root')  
		) ToList  
	   ,(SELECT c.ContactEmail  
				,c.ContactName  
				,c.IsMain  
			FROM dbo.CategoryContact cc WITH(NOLOCK)  
				INNER JOIN dbo.Contact c WITH(NOLOCK)   
					ON c.ContactID = cc.ContactID   
					   AND cc.RecipientType = 1   
					   AND cc.CategoryID = lc.CategoryId   
					   AND c.LicenseeID = t.LicenseeId  
			FOR XML RAW('row'), ROOT('root')  
		) CcList  
	FROM #tblResult t  
		INNER JOIN dbo.LicenseeCategoryAssigned lc    
			ON t.LicenseeId = lc.LicenseeId  
		INNER JOIN @tblCategory c   
			ON c.CategoryId = lc.CategoryId  
	WHERE t.RowNumber BETWEEN @RowStart AND @RowEnd  
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeCategoryListSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OIC_LicenseeCategoryListSel_xtest]   
	@UserId					INT  
	,@SelectedLicenseeType	VARCHAR(50)	= 'All'
	,@LicenseeName			NVARCHAR(50) = '%'  
	,@StatusIds				VARCHAR(50)	= 'All'
	,@SelectedCategory		VARCHAR(500) = 'All'  
   
	,@PageSize				INT = 10  
	,@PageIndex				INT = 0  
	,@TotalRecords			INT = 0 OUTPUT  
AS  
/*  
	Created by: Kathy  
	Date: 2015-03-31  
	Task: Licensee category mailing list [Redmine:#29611]  
	DB: DBOIC.bodb_OIC  
   
	Revisions:  
		- 20160818@Percy: Return new column: CategoryNameCN -- Add Chinese name [RedmineID: #62642]
		- 20161214@Percy: Change dropdown TOL filter multiple choices [RedmineID: #68774]
		- 20170828@Scofield: Update LicenseeStatusIds [#82144]
   
	Param's Explanation:  
		@SelectedCategory: support multiple selection  
		@PageIndex: 0 - the first page  
    
 */  
BEGIN  
 
	SET NOCOUNT ON  
   
	DECLARE @RowCount INT   
		,@RowStart INT  
		,@RowEnd INT  
     
	SELECT @PageIndex = @PageIndex ,  
		@RowStart = @PageSize * @PageIndex + 1  
		,@RowEnd = @RowStart + @PageSize - 1  
     
	DECLARE @tblCategory     TABLE (CategoryId TINYINT, CategoryName VARCHAR(100), CategoryNameCN NVARCHAR(200))         
	DECLARE @tblLicenseeCategoryAssigned TABLE (LicenseeId INT)  
	DECLARE @tblLicenseeType    TABLE (LicenseeTypeId TINYINT)  
	CREATE TABLE #tblResult (  
		RowNumber		INT  
		,LicenseeId		INT  
		,LicenseeName	NVARCHAR(50)  
		,StatusName		VARCHAR(30)  
		,TypeName		VARCHAR(30)  
	)  
   
	INSERT INTO @tblCategory (CategoryId, CategoryName, CategoryNameCN)  
	SELECT CategoryId, CategoryName, CategoryNameCN  
	FROM dbo.Category   
	WHERE
		@SelectedCategory = 'All'  
		OR CategoryId IN (SELECT val FROM dbo.strSplit(@SelectedCategory,',' ))  
   
	INSERT INTO @tblLicenseeCategoryAssigned (LicenseeId)        
	SELECT lc.LicenseeId  
	FROM dbo.LicenseeCategoryAssigned lc WITH(NOLOCK)  
		INNER JOIN @tblCategory c   
			ON lc.CategoryId = c.CategoryId  
	GROUP BY lc.LicenseeId  
	HAVING COUNT(DISTINCT lc.CategoryId) = CASE WHEN @SelectedCategory = 'All' THEN COUNT(DISTINCT lc.CategoryId) ELSE (SELECT COUNT(1) FROM @tblCategory) END           
            
	IF @SelectedLicenseeType = 'All'
	BEGIN
		INSERT INTO @tblLicenseeType (LicenseeTypeId)
		SELECT	LicenseeTypeId
		FROM	dbo.UserLicenseeType WITH(NOLOCK)
		WHERE	UserId = @UserId
	END
	ELSE
	BEGIN
		INSERT INTO @tblLicenseeType (LicenseeTypeId)
		SELECT CONVERT(TINYINT, val) FROM dbo.strSplit(@SelectedLicenseeType, ',')

		DELETE lt
		FROM @tblLicenseeType lt
			LEFT JOIN dbo.UserLicenseeType ult WITH(NOLOCK) ON lt.LicenseeTypeId = ult.LicenseeTypeId AND ult.UserId = @UserId
		WHERE ult.LicenseeTypeId IS NULL
	END
     
	INSERT INTO #tblResult(  
		RowNumber  
		,LicenseeId  
		,LicenseeName  
		,StatusName  
		,TypeName  
	)       
	SELECT ROW_NUMBER() OVER(ORDER BY l.LicenseeName) AS RowNumber  
		,l.LicenseeId  
		,l.LicenseeName  
		,ls.LicenseeStatusName  
		,lt.LicenseeTypeName  
	FROM dbo.Licensee l WITH(NOLOCK)  
		INNER JOIN dbo.LicenseeStatus ls WITH(NOLOCK)   
			ON l.LicenseeStatusId = ls.LicenseeStatusId  
		INNER JOIN dbo.LicenseeType lt WITH(NOLOCK)   
			ON l.LicenseeTypeId = lt.LicenseeTypeId  
	WHERE l.LicenseeTypeId IN (SELECT LicenseeTypeId FROM @tblLicenseeType)  
		AND (@StatusIds = 'All' OR ls.LicenseeStatusId IN (SELECT val FROM dbo.strSplit(@StatusIds,',')))  
		AND l.LicenseeName LIKE @LicenseeName + '%'  
		AND l.LicenseeId IN (SELECT LicenseeId FROM @tblLicenseeCategoryAssigned)  
      
	IF @TotalRecords = 0  
	BEGIN  
		SELECT @TotalRecords = COUNT(1)  
		FROM #tblResult  
	END   
   
	SELECT LicenseeId  
		,LicenseeName  
		,StatusName  
		,TypeName  
	FROM #tblResult  
	WHERE RowNumber BETWEEN @RowStart AND @RowEnd  
   
	SELECT t.LicenseeId  
		,lc.CategoryId  
		,c.CategoryName
		,c.CategoryNameCN
		,(SELECT c.ContactEmail  
				,c.ContactName  
				,c.IsMain  
			FROM dbo.CategoryContact cc WITH(NOLOCK)  
				INNER JOIN dbo.Contact c WITH(NOLOCK)   
					ON c.ContactID = cc.ContactID   
						AND cc.RecipientType = 0   
						AND cc.CategoryID = lc.CategoryId   
						AND c.LicenseeID = t.LicenseeId  
			FOR XML RAW('row'), ROOT('root')  
		) ToList  
	   ,(SELECT c.ContactEmail  
				,c.ContactName  
				,c.IsMain  
			FROM dbo.CategoryContact cc WITH(NOLOCK)  
				INNER JOIN dbo.Contact c WITH(NOLOCK)   
					ON c.ContactID = cc.ContactID   
					   AND cc.RecipientType = 1   
					   AND cc.CategoryID = lc.CategoryId   
					   AND c.LicenseeID = t.LicenseeId  
			FOR XML RAW('row'), ROOT('root')  
		) CcList  
	FROM #tblResult t  
		INNER JOIN dbo.LicenseeCategoryAssigned lc    
			ON t.LicenseeId = lc.LicenseeId  
		INNER JOIN @tblCategory c   
			ON c.CategoryId = lc.CategoryId  
	WHERE t.RowNumber BETWEEN @RowStart AND @RowEnd  
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeCategoryManage]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeCategoryManage    Script Date: 11/21/2016 10:53:57 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeCategoryManage    Script Date: 11/11/2016 10:29:58 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeCategoryManage] 
	@SelectedCategory	VARCHAR(500)
	,@SelectedLicensee	VARCHAR(500)
	,@ActionId			BIT = 1 -- Add
	
	,@UserId			INT
	,@Language			VARCHAR(10)		= 'E'
	,@IP				VARCHAR(50)		= NULL
	,@ErrCode			INT				= 0			OUTPUT
	,@ErrMsg			VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2015-03-31
	Task: Assign categories to clients [Redmine:#29611]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160928@Percy: Add nested SPs to write log for insert and delete Category [RedmineID: #64713]
	
	Param's Explanation:
		*@SelectedLicensee: '1,2,3,4'
		*@SelectedCategory: '1,2,3,4'
		*@ActionId: 1- Add
					0- Remove
		
		
 */
BEGIN
	SET NOCOUNT ON

	IF @ActionId = 1 -- assign category to client
	BEGIN
				EXEC dbo.OIC_LicenseeCategoryIns
			@SelectedCategory	= @SelectedCategory
			,@SelectedLicensee	= @SelectedLicensee
			,@UserId			= @UserId
			,@Language			= @Language
			,@IP				= @IP
			,@ErrCode			= @ErrCode		OUTPUT
			,@ErrMsg			= @ErrMsg		OUTPUT
	END
	ELSE
	BEGIN		
				EXEC dbo.OIC_LicenseeCategoryDel
			@SelectedCategory	= @SelectedCategory
			,@SelectedLicensee	= @SelectedLicensee
			,@UserId			= @UserId
			,@Language			= @Language
			,@IP				= @IP
			,@ErrCode			= @ErrCode		OUTPUT
			,@ErrMsg			= @ErrMsg		OUTPUT
	END
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeCategoryManage_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeCategoryManage_xtest    Script Date: 11/11/2016 10:29:58 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeCategoryManage_xtest] 
	@SelectedCategory	VARCHAR(500)
	,@SelectedLicensee	VARCHAR(500)
	,@ActionId			BIT = 1 -- Add
	
	,@UserId			INT
	,@Language			VARCHAR(10)		= 'E'
	,@IP				VARCHAR(50)		= NULL
	,@ErrCode			INT				= 0			OUTPUT
	,@ErrMsg			VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2015-03-31
	Task: Assign categories to clients [Redmine:#29611]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160928@Percy: Add nested SPs to write log for insert and delete Category [RedmineID: #64713]
	
	Param's Explanation:
		*@SelectedLicensee: '1,2,3,4'
		*@SelectedCategory: '1,2,3,4'
		*@ActionId: 1- Add
					0- Remove
		
		
 */
BEGIN
	SET NOCOUNT ON

	IF @ActionId = 1 -- assign category to client
	BEGIN
		EXEC dbo.OIC_LicenseeCategoryIns_xtest
			@SelectedCategory	= @SelectedCategory
			,@SelectedLicensee	= @SelectedLicensee
			,@UserId			= @UserId
			,@Language			= @Language
			,@IP				= @IP
			,@ErrCode			= @ErrCode		OUTPUT
			,@ErrMsg			= @ErrMsg		OUTPUT
	END
	ELSE
	BEGIN		
		EXEC dbo.OIC_LicenseeCategoryDel_xtest
			@SelectedCategory	= @SelectedCategory
			,@SelectedLicensee	= @SelectedLicensee
			,@UserId			= @UserId
			,@Language			= @Language
			,@IP				= @IP
			,@ErrCode			= @ErrCode		OUTPUT
			,@ErrMsg			= @ErrMsg		OUTPUT
	END
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeCategorySel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeCategorySel    Script Date: 15/05/2015 10:19:11 AM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeCategorySel    Script Date: 16/04/2015 9:22:41 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeCategorySel] 
	@LicenseeId			INT
	,@CategoryId		TINYINT
AS
/*
	Created by: Kathy
	Date: 2015-03-31
	Task: get all licensee's contact belong to licensee [Redmine:#29611]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	Param's Explanation:
		
		
 */
BEGIN
	SET NOCOUNT ON

	SELECT	lc.ContactID
			,lc.ContactName
			,lc.ContactEmail AS Email
			,(SELECT	cc.RecipientType 
			  FROM dbo.CategoryContact cc WITH(NOLOCK) 
			  WHERE		cc.ContactID = lc.ContactID 
					AND cc.CategoryID = @CategoryId 
			  )	AS ToCc	-- 0: To, 1: Cc, NULL: none
			,ISNULL(lc.IsMain, 0) AS IsMain
	FROM dbo.Contact lc WITH(NOLOCK) 
	WHERE	lc.LicenseeID = @LicenseeId
	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeCategoryUpd]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeCategoryUpd    Script Date: 11/21/2016 10:53:58 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeCategoryUpd    Script Date: 11/11/2016 10:29:58 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeCategoryUpd] 
	@LicenseeId				INT			 
	,@CategoryId			TINYINT
	,@SelectedTo			VARCHAR(500)	= ''
	,@SelectedCc			VARCHAR(500)	= ''
	
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2015-03-31
	Task: Edit licensee category mailing  [Redmine:#29611]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	Param's Explanation:
		
		
 */
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPOlddata	NVARCHAR(MAX)	
		,@xml			XML
		,@procName		VARCHAR(200)
		,@ProductName	VARCHAR(50)
		,@LicenseeName	NVARCHAR(50)
		,@CategoryName	VARCHAR(100)

	SET @startRun = GETDATE()
	
	SELECT	@LicenseeName = l.LicenseeName
			,@CategoryName = c.CategoryName
	FROM dbo.Licensee l WITH(NOLOCK)
		INNER JOIN dbo.LicenseeCategoryAssigned lc WITH(NOLOCK) ON l.LicenseeId = lc.LicenseeId AND l.LicenseeId = @LicenseeId
		INNER JOIN dbo.Category c WITH(NOLOCK) ON c.CategoryId = lc.CategoryId AND c.CategoryId = @CategoryId
	
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1502, @Language) -- Category does not belong to Licensee
		RETURN
	END
	
	DECLARE @tblToCcList TABLE(ContactId INT, RecipientType	TINYINT)
	INSERT INTO @tblToCcList (ContactId, RecipientType)
	SELECT CONVERT(INT, val), 0
	FROM dbo.strSplit(@SelectedTo, ',') WHERE @SelectedTo <> ''
	UNION ALL
	SELECT CONVERT(INT, val), 1
	FROM dbo.strSplit(@SelectedCc, ',') WHERE @SelectedCc <> ''

	-- get data before update/insert
	SET @xml = (SELECT @LicenseeId				AS '@lid'
					,@LicenseeName				AS '@ln'
					,@CategoryId				AS '@cid'
					,@CategoryName				AS '@cn'
					,(SELECT lc.ContactID		AS '@lcc'
							,lc.ContactName		AS '@lcn'
							,lc.ContactEmail	AS '@lce'
							,cc.RecipientType	AS '@cct'
						FROM dbo.Contact AS lc WITH (NOLOCK)
							INNER JOIN dbo.CategoryContact cc WITH(NOLOCK) 
								ON lc.ContactId = cc.ContactId 
									AND cc.CategoryId = @CategoryId 
									AND lc.LicenseeID = @LicenseeId						
						FOR XML PATH('row'), TYPE, ROOT('cc'))
			FOR XML PATH('r'))		
			
	SELECT @logSPOldData = CONVERT(NVARCHAR(MAX), @xml)
	
	BEGIN TRY	
		DELETE cc WITH(ROWLOCK, UPDLOCK)
		FROM dbo.CategoryContact cc
			INNER JOIN dbo.Contact c WITH (NOLOCK) ON cc.ContactId = c.ContactId AND c.LicenseeId = @LicenseeId
		WHERE cc.CategoryId = @CategoryId AND cc.ContactId NOT IN (SELECT ContactId FROM @tblToCcList)
				
		MERGE dbo.CategoryContact cc
		USING (SELECT ContactId, RecipientType FROM @tblToCcList) t
			ON (cc.ContactID = t.ContactId AND cc.CategoryID = @CategoryId)
		WHEN MATCHED AND cc.RecipientType <> t.RecipientType THEN UPDATE SET cc.RecipientType = t.RecipientType
		WHEN NOT MATCHED BY TARGET THEN INSERT (ContactID, CategoryID, RecipientType) VALUES (t.ContactId, @CategoryId, t.RecipientType);
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 102
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1503, @Language) -- Fail to update mailing list. Please try again.
		RETURN
	END CATCH
	
	-- Write log
	SET @xml = (SELECT @LicenseeId				AS '@lid'
					,@LicenseeName				AS '@ln'
					,@CategoryId				AS '@cid'
					,@CategoryName				AS '@cn'
					,(SELECT lc.ContactID		AS '@lcc'
							,lc.ContactName		AS '@lcn'
							,lc.ContactEmail	AS '@lce'
							,cc.RecipientType	AS '@cct'
						FROM dbo.Contact AS lc WITH (NOLOCK)
							INNER JOIN dbo.CategoryContact cc WITH(NOLOCK) 
								ON lc.ContactId = cc.ContactId 
									AND cc.CategoryId = @CategoryId 
									AND lc.LicenseeID = @LicenseeId
						WHERE cc.ContactId IN (SELECT t.ContactId FROM @tblToCcList t)
						FOR XML PATH('row'), TYPE, ROOT('cc'))
			FOR XML PATH('r'))		
		
	SELECT	@logSPData = CONVERT(NVARCHAR(MAX), @xml)
			,@endRun	= GETDATE()  
			,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
			,@procName	= OBJECT_NAME(@@PROCID)
	
		EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOlddata
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeCategoryUpd_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeCategoryUpd_xtest    Script Date: 11/11/2016 10:29:58 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeCategoryUpd_xtest] 
	@LicenseeId				INT			 
	,@CategoryId			TINYINT
	,@SelectedTo			VARCHAR(500)	= ''
	,@SelectedCc			VARCHAR(500)	= ''
	
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2015-03-31
	Task: Edit licensee category mailing  [Redmine:#29611]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	Param's Explanation:
		
		
 */
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPOlddata	NVARCHAR(MAX)	
		,@xml			XML
		,@procName		VARCHAR(200)
		,@ProductName	VARCHAR(50)
		,@LicenseeName	NVARCHAR(50)
		,@CategoryName	VARCHAR(100)

	SET @startRun = GETDATE()
	
	SELECT	@LicenseeName = l.LicenseeName
			,@CategoryName = c.CategoryName
	FROM dbo.Licensee l WITH(NOLOCK)
		INNER JOIN dbo.LicenseeCategoryAssigned lc WITH(NOLOCK) ON l.LicenseeId = lc.LicenseeId AND l.LicenseeId = @LicenseeId
		INNER JOIN dbo.Category c WITH(NOLOCK) ON c.CategoryId = lc.CategoryId AND c.CategoryId = @CategoryId
	
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1502, @Language) -- Category does not belong to Licensee
		RETURN
	END
	
	DECLARE @tblToCcList TABLE(ContactId INT, RecipientType	TINYINT)
	INSERT INTO @tblToCcList (ContactId, RecipientType)
	SELECT CONVERT(INT, val), 0
	FROM dbo.strSplit(@SelectedTo, ',') WHERE @SelectedTo <> ''
	UNION ALL
	SELECT CONVERT(INT, val), 1
	FROM dbo.strSplit(@SelectedCc, ',') WHERE @SelectedCc <> ''

	-- get data before update/insert
	SET @xml = (SELECT @LicenseeId				AS '@lid'
					,@LicenseeName				AS '@ln'
					,@CategoryId				AS '@cid'
					,@CategoryName				AS '@cn'
					,(SELECT lc.ContactID		AS '@lcc'
							,lc.ContactName		AS '@lcn'
							,lc.ContactEmail	AS '@lce'
							,cc.RecipientType	AS '@cct'
						FROM dbo.Contact AS lc WITH (NOLOCK)
							INNER JOIN dbo.CategoryContact cc WITH(NOLOCK) 
								ON lc.ContactId = cc.ContactId 
									AND cc.CategoryId = @CategoryId 
									AND lc.LicenseeID = @LicenseeId						
						FOR XML PATH('row'), TYPE, ROOT('cc'))
			FOR XML PATH('r'))		
			
	SELECT @logSPOldData = CONVERT(NVARCHAR(MAX), @xml)
	
	BEGIN TRY	
		DELETE cc WITH(ROWLOCK, UPDLOCK)
		FROM dbo.CategoryContact cc
			INNER JOIN dbo.Contact c WITH (NOLOCK) ON cc.ContactId = c.ContactId AND c.LicenseeId = @LicenseeId
		WHERE cc.CategoryId = @CategoryId AND cc.ContactId NOT IN (SELECT ContactId FROM @tblToCcList)
				
		MERGE dbo.CategoryContact cc
		USING (SELECT ContactId, RecipientType FROM @tblToCcList) t
			ON (cc.ContactID = t.ContactId AND cc.CategoryID = @CategoryId)
		WHEN MATCHED AND cc.RecipientType <> t.RecipientType THEN UPDATE SET cc.RecipientType = t.RecipientType
		WHEN NOT MATCHED BY TARGET THEN INSERT (ContactID, CategoryID, RecipientType) VALUES (t.ContactId, @CategoryId, t.RecipientType);
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 102
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1503, @Language) -- Fail to update mailing list. Please try again.
		RETURN
	END CATCH
	
	-- Write log
	SET @xml = (SELECT @LicenseeId				AS '@lid'
					,@LicenseeName				AS '@ln'
					,@CategoryId				AS '@cid'
					,@CategoryName				AS '@cn'
					,(SELECT lc.ContactID		AS '@lcc'
							,lc.ContactName		AS '@lcn'
							,lc.ContactEmail	AS '@lce'
							,cc.RecipientType	AS '@cct'
						FROM dbo.Contact AS lc WITH (NOLOCK)
							INNER JOIN dbo.CategoryContact cc WITH(NOLOCK) 
								ON lc.ContactId = cc.ContactId 
									AND cc.CategoryId = @CategoryId 
									AND lc.LicenseeID = @LicenseeId
						WHERE cc.ContactId IN (SELECT t.ContactId FROM @tblToCcList t)
						FOR XML PATH('row'), TYPE, ROOT('cc'))
			FOR XML PATH('r'))		
		
	SELECT	@logSPData = CONVERT(NVARCHAR(MAX), @xml)
			,@endRun	= GETDATE()  
			,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
			,@procName	= OBJECT_NAME(@@PROCID)
	
	EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOlddata
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeContactDel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeContactDel    Script Date: 11/21/2016 10:53:59 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeContactDel    Script Date: 11/11/2016 10:29:58 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeContactDel]
	@ContactId		INT
	
	,@UserId		INT
	,@Language		VARCHAR(10)		= 'E'
	,@IP			VARCHAR(50)		= NULL
	,@ErrCode		INT				= 0			OUTPUT
	,@ErrMsg		VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2015-02-09
	Task: Delete licensee contact [Redmine:#29610]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	Param's Explanation:
	*
*/
BEGIN
	SET NOCOUNT ON
		-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
		,@log_category	XML
		
	SET @startRun = GETDATE()

	-- Write log
	-- get data to write log
	SET @log_category = (
						SELECT c.CategoryName AS '@cn'
								,cc.RecipientType AS '@ct'
						FROM dbo.Category AS c WITH (NOLOCK)
							INNER JOIN dbo.CategoryContact AS cc WITH(NOLOCK) 
								ON c.CategoryId = cc.CategoryID
						WHERE cc.ContactID = @ContactId
						FOR XML PATH('row'), ROOT('cc')	
					)

	SET @xml = (
		SELECT	@ContactId				AS '@lcid'
				,LicenseeId				AS '@lid'
				,c.ContactName			AS '@lccn'			
				,c.ContactPosition		AS '@lcp'
				,c.ContactDepartment	AS '@lcd'
				,c.ContactEmail			AS '@lce'
				,c.ContactSkype			AS '@lcs'
				,c.ContactPhoneNumber	AS '@lcpn'
				,c.ContactLandline		AS '@lcll'
				,c.ContactType			AS '@lcct'
				,c.Remark				AS '@lcr'
				,@log_category
		FROM dbo.Contact c WITH(NOLOCK)
		WHERE c.ContactID = @ContactId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT	@logSPData = CONVERT(NVARCHAR(MAX),@xml)
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.Contact WITH(NOLOCK) WHERE ContactID = @ContactId)
	BEGIN
		DELETE 
		FROM dbo.Contact WITH(ROWLOCK, UPDLOCK)
		WHERE	ContactID = @ContactId
		
		IF @@ERROR <> 0
		BEGIN
			SELECT	@ErrCode = 100
					,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](502, @Language) -- Failed to delete contact. Please try again!
			RETURN
		END
	END
	
	
	SELECT	@endRun		= GETDATE()  
			,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
			,@procName	= OBJECT_NAME(@@PROCID)

		EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= NULL
		,@OldData		= @logSPData
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeContactDel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeContactDel_xtest    Script Date: 11/11/2016 10:29:58 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeContactDel_xtest]
	@ContactId		INT
	
	,@UserId		INT
	,@Language		VARCHAR(10)		= 'E'
	,@IP			VARCHAR(50)		= NULL
	,@ErrCode		INT				= 0			OUTPUT
	,@ErrMsg		VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2015-02-09
	Task: Delete licensee contact [Redmine:#29610]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	Param's Explanation:
	*
*/
BEGIN
	SET NOCOUNT ON
		-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
		,@log_category	XML
		
	SET @startRun = GETDATE()

	-- Write log
	-- get data to write log
	SET @log_category = (
						SELECT c.CategoryName AS '@cn'
								,cc.RecipientType AS '@ct'
						FROM dbo.Category AS c WITH (NOLOCK)
							INNER JOIN dbo.CategoryContact AS cc WITH(NOLOCK) 
								ON c.CategoryId = cc.CategoryID
						WHERE cc.ContactID = @ContactId
						FOR XML PATH('row'), ROOT('cc')	
					)

	SET @xml = (
		SELECT	@ContactId				AS '@lcid'
				,LicenseeId				AS '@lid'
				,c.ContactName			AS '@lccn'			
				,c.ContactPosition		AS '@lcp'
				,c.ContactDepartment	AS '@lcd'
				,c.ContactEmail			AS '@lce'
				,c.ContactSkype			AS '@lcs'
				,c.ContactPhoneNumber	AS '@lcpn'
				,c.ContactLandline		AS '@lcll'
				,c.ContactType			AS '@lcct'
				,c.Remark				AS '@lcr'
				,@log_category
		FROM dbo.Contact c WITH(NOLOCK)
		WHERE c.ContactID = @ContactId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT	@logSPData = CONVERT(NVARCHAR(MAX),@xml)
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.Contact WITH(NOLOCK) WHERE ContactID = @ContactId)
	BEGIN
		DELETE 
		FROM dbo.Contact WITH(ROWLOCK, UPDLOCK)
		WHERE	ContactID = @ContactId
		
		IF @@ERROR <> 0
		BEGIN
			SELECT	@ErrCode = 100
					,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](502, @Language) -- Failed to delete contact. Please try again!
			RETURN
		END
	END
	
	
	SELECT	@endRun		= GETDATE()  
			,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
			,@procName	= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= NULL
		,@OldData		= @logSPData
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeContactIns]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeContactIns    Script Date: 11/21/2016 10:53:59 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeContactIns    Script Date: 11/11/2016 10:29:58 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeContactIns]
	@UserId					INT
	,@LicenseeId			INT
	,@ContactType			BIT
	,@ContactName			NVARCHAR(50)
	,@Position				NVARCHAR(50)
	,@Department			NVARCHAR(50) 
	,@Email					VARCHAR(50)
	,@Skype					VARCHAR(50)
	,@PhoneNumber			VARCHAR(50)		= NULL
	,@LandLine				VARCHAR(50)		= NULL
	,@Remark				NVARCHAR(300)	= NULL
	
	,@SelectedCategories	XML
	 
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2015-02-04
	Task: Add new contact [Redmine:#29607]
	DB: DBOIC.bodb_OIC 
	
	Revisions:
	
	Param's Explanation:
	- @ContactType: 0 - Individual
					1 - Group
	- @SelectedCategorie: 
		<root>
			<row id="1" type="1" />
			<row id="2" type="0" />
		</root>
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @ContactId INT
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
		,@log_category	XML

	SET @startRun = GETDATE()			
	
	BEGIN TRY
		INSERT INTO dbo.Contact (
			LicenseeID
			,ContactName
			,ContactPosition
			,ContactDepartment
			,ContactEmail
			,ContactSkype
			,ContactPhoneNumber
			,ContactLandline
			,ContactType
			,Remark		
		)
		VALUES(
			@LicenseeId
			,@ContactName
			,@Position
			,@Department
			,@Email
			,@Skype
			,@PhoneNumber
			,@Landline
			,@ContactType
			,@Remark
		)
	
	SET @ContactId = SCOPE_IDENTITY()
	
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](500, @Language) -- Failed to add new contact. Please try again
		RETURN
	END CATCH
	
	;WITH selectedCategory
	AS (
		SELECT	@ContactId				AS ContactId
			,t.c.value('@id','int')		AS CategoryId
			,t.c.value('@type', 'bit')	AS Value
		FROM @SelectedCategories.nodes('root/row') t(c)
	)
	INSERT INTO dbo.CategoryContact (
			ContactID
			,CategoryID
			,RecipientType
	)
	SELECT	ContactId
			,s.CategoryId
			,s.Value
	FROM selectedCategory s 
		INNER JOIN dbo.LicenseeCategoryAssigned l WITH(NOLOCK) ON s.CategoryId = l.CategoryId AND l.LicenseeId = @LicenseeId	
	
	IF @@ERROR <> 0
	BEGIN
		DELETE FROM dbo.Contact WITH(ROWLOCK, UPDLOCK)
		WHERE ContactID = @ContactId
		
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](500, @Language) -- 
		RETURN
	END
	
	-- Write log
	-- get data to write log
	SET @log_category = (
						SELECT c.CategoryName AS '@cn'
								,cc.RecipientType AS '@ct'
						FROM dbo.Category AS c WITH (NOLOCK)
							INNER JOIN dbo.CategoryContact AS cc WITH(NOLOCK) 
								ON c.CategoryId = cc.CategoryID
						WHERE cc.ContactID = @ContactId
						FOR XML PATH('row'), ROOT('cc')	
					)
					
	SET @xml = (
		SELECT	@ContactId				AS '@lcid'
				,LicenseeId				AS '@lid'
				,c.ContactName			AS '@lccn'			
				,c.ContactPosition		AS '@lcp'
				,c.ContactDepartment	AS '@lcd'
				,c.ContactEmail			AS '@lce'
				,c.ContactSkype			AS '@lcs'
				,c.ContactPhoneNumber	AS '@lcpn'
				,c.ContactLandline		AS '@lcll'
				,c.ContactType			AS '@lcct'
				,c.Remark				AS '@lcr'
				,@log_category
		FROM dbo.Contact AS c WITH (NOLOCK)
		WHERE	c.ContactID = @ContactId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX),@xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@procid)

		EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration
	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeContactIns_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeContactIns_xtest    Script Date: 11/11/2016 10:29:58 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeContactIns_xtest]
	@UserId					INT
	,@LicenseeId			INT
	,@ContactType			BIT
	,@ContactName			NVARCHAR(50)
	,@Position				NVARCHAR(50)
	,@Department			NVARCHAR(50) 
	,@Email					VARCHAR(50)
	,@Skype					VARCHAR(50)
	,@PhoneNumber			VARCHAR(50)		= NULL
	,@LandLine				VARCHAR(50)		= NULL
	,@Remark				NVARCHAR(300)	= NULL
	
	,@SelectedCategories	XML
	 
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2015-02-04
	Task: Add new contact [Redmine:#29607]
	DB: DBOIC.bodb_OIC 
	
	Revisions:
	
	Param's Explanation:
	- @ContactType: 0 - Individual
					1 - Group
	- @SelectedCategorie: 
		<root>
			<row id="1" type="1" />
			<row id="2" type="0" />
		</root>
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @ContactId INT
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
		,@log_category	XML

	SET @startRun = GETDATE()			
	
	BEGIN TRY
		INSERT INTO dbo.Contact (
			LicenseeID
			,ContactName
			,ContactPosition
			,ContactDepartment
			,ContactEmail
			,ContactSkype
			,ContactPhoneNumber
			,ContactLandline
			,ContactType
			,Remark		
		)
		VALUES(
			@LicenseeId
			,@ContactName
			,@Position
			,@Department
			,@Email
			,@Skype
			,@PhoneNumber
			,@Landline
			,@ContactType
			,@Remark
		)
	
	SET @ContactId = SCOPE_IDENTITY()
	
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](500, @Language) -- Failed to add new contact. Please try again
		RETURN
	END CATCH
	
	;WITH selectedCategory
	AS (
		SELECT	@ContactId				AS ContactId
			,t.c.value('@id','int')		AS CategoryId
			,t.c.value('@type', 'bit')	AS Value
		FROM @SelectedCategories.nodes('root/row') t(c)
	)
	INSERT INTO dbo.CategoryContact (
			ContactID
			,CategoryID
			,RecipientType
	)
	SELECT	ContactId
			,s.CategoryId
			,s.Value
	FROM selectedCategory s 
		INNER JOIN dbo.LicenseeCategoryAssigned l WITH(NOLOCK) ON s.CategoryId = l.CategoryId AND l.LicenseeId = @LicenseeId	
	
	IF @@ERROR <> 0
	BEGIN
		DELETE FROM dbo.Contact WITH(ROWLOCK, UPDLOCK)
		WHERE ContactID = @ContactId
		
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](500, @Language) -- 
		RETURN
	END
	
	-- Write log
	-- get data to write log
	SET @log_category = (
						SELECT c.CategoryName AS '@cn'
								,cc.RecipientType AS '@ct'
						FROM dbo.Category AS c WITH (NOLOCK)
							INNER JOIN dbo.CategoryContact AS cc WITH(NOLOCK) 
								ON c.CategoryId = cc.CategoryID
						WHERE cc.ContactID = @ContactId
						FOR XML PATH('row'), ROOT('cc')	
					)
					
	SET @xml = (
		SELECT	@ContactId				AS '@lcid'
				,LicenseeId				AS '@lid'
				,c.ContactName			AS '@lccn'			
				,c.ContactPosition		AS '@lcp'
				,c.ContactDepartment	AS '@lcd'
				,c.ContactEmail			AS '@lce'
				,c.ContactSkype			AS '@lcs'
				,c.ContactPhoneNumber	AS '@lcpn'
				,c.ContactLandline		AS '@lcll'
				,c.ContactType			AS '@lcct'
				,c.Remark				AS '@lcr'
				,@log_category
		FROM dbo.Contact AS c WITH (NOLOCK)
		WHERE	c.ContactID = @ContactId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX),@xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@procid)

	EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration
	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeContactListSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeContactListSel    Script Date: 9/29/2016 4:36:44 AM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeContactListSel    Script Date: 9/29/2016 1:04:12 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeContactListSel    Script Date: 9/29/2016 8:37:11 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeContactListSel]
    @UserId        INT
    ,@LicenseeName NVARCHAR(50)
    ,@ContactName  NVARCHAR(50)    = ''
    
    ,@PageSize			INT = 10
	,@PageIndex			INT	= 0 
	,@TotalRecords		INT = 0 OUTPUT
AS
/*
    Created by: Kathy
    Date: 2015-02-04
    Task: Licensee contact list [Redmine:#29610]
    DB: DBOIC/BODB_OIC 
    
    Revisions:
		- 20160920@Percy: Add new return field: Change History [RedmineID: #]
    
    Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON
    
    DECLARE @tblContactList TABLE(ContactId INT)
    DECLARE @ToList		VARCHAR(1000)
			,@CcList	VARCHAR(1000)
			,@RowCount	INT	
			,@RowStart	INT
			,@RowEnd	INT
    
    INSERT INTO @tblContactList(ContactId)
    SELECT	c.ContactID    
    FROM	dbo.Contact c WITH(NOLOCK)
		INNER JOIN dbo.Licensee l WITH(NOLOCK) 
			ON	c.LicenseeID = l.LicenseeId
    WHERE	l.LicenseeTypeId IN (SELECT		u.LicenseeTypeId 
									FROM	dbo.UserLicenseeType u WITH(NOLOCK) 
									WHERE	u.UserId = @UserId)
			AND l.LicenseeName = @LicenseeName
			AND c.ContactName LIKE @ContactName + '%'    
    
    -- General info
    SELECT ROW_NUMBER() OVER (ORDER BY lc.IsMain DESC, lc.ContactName) AS RowNumber
			,lc.ContactID
			,lc.ContactName
			,lc.ContactType 
			,lc.ContactPosition		AS Position
			,lc.ContactDepartment	AS Department
			,lc.ContactPhoneNumber	AS PhoneNumber
			,lc.ContactEmail		AS Email
			,lc.ContactSkype		AS Skype
			,lc.ContactLandline		AS Landline
			,lc.Remark
			,(SELECT ISNULL(@ToList,'') + c.CategoryName + ','  
				FROM dbo.CategoryContact cc WITH(NOLOCK)
					INNER JOIN dbo.Category c WITH(NOLOCK) 
						ON c.CategoryId = cc.CategoryID
				WHERE cc.ContactID = lc.ContactID 
						AND cc.RecipientType = 0 
				FOR XML PATH('')
			  ) AS ToList
			,(SELECT ISNULL(@CcList,'') + c.CategoryName + ','  
				FROM dbo.CategoryContact cc WITH(NOLOCK)
					INNER JOIN dbo.Category c WITH(NOLOCK) 
						ON c.CategoryId = cc.CategoryID
				WHERE cc.ContactID = lc.ContactID 
						AND cc.RecipientType = 1
			   FOR XML PATH('')
			  ) AS CcList
			 ,lc.IsMain
    INTO	#tblResult
    FROM	dbo.Contact lc WITH(NOLOCK)
    WHERE	lc.ContactID IN (SELECT ContactID FROM @tblContactList)
    
	SELECT @PageIndex	= @PageIndex ,
		@RowStart		= @PageSize * @PageIndex + 1
		,@RowEnd		= @RowStart + @PageSize - 1
	
	IF @TotalRecords = 0
	BEGIN
		SELECT	@TotalRecords	= COUNT(1)
		FROM	#tblResult
	END

	-- Get log latest update contact --
	DECLARE @LogActionId_Ins INT, @LogActionId_Upd INT

	SELECT  @LogActionId_Ins = LogActionId FROM dbo.LogAction WITH(NOLOCK) WHERE SPName = 'OIC_LicenseeContactIns'
	SELECT  @LogActionId_Upd = LogActionId FROM dbo.LogAction WITH(NOLOCK) WHERE SPName = 'OIC_LicenseeContactUpd'

	CREATE TABLE #LogContact (Id BIGINT PRIMARY KEY, LogActionId INT, UserId INT, LogDate DATETIME, ContactId INT)
	INSERT INTO  #LogContact (Id, LogActionId, UserId, LogDate, ContactId)
	SELECT
		A.Id, A.LogActionId, A.UserId, A.LogDate,
		d.c.value('@lcid','INT') AS ContactId -- ContactId
	FROM (
		SELECT u.Id, u.LogActionId, u.UserId, u.LogDate, CONVERT(XML, ud.Data) AS Data
		FROM dbo.UserLog_RunSP u WITH(NOLOCK)
			INNER JOIN dbo.UserLog_RunSP_Detail ud WITH(NOLOCK) ON u.Id = ud.Id
		WHERE u.LogActionId IN (@LogActionId_Ins, @LogActionId_Upd)
	) AS A
	CROSS APPLY A.Data.nodes('r') d(c)
	-- End get log --

	CREATE NONCLUSTERED INDEX IX_ContactId ON #LogContact (ContactId, LogActionId)

	;WITH CTE_Update AS (
		SELECT u1.DisplayName, A.LogDate, A.ContactId FROM (
			SELECT ROW_NUMBER() OVER(PARTITION BY ContactId ORDER BY Id DESC) AS RowNumber
					, UserId, LogDate, ContactId
			FROM #LogContact
			WHERE LogActionId = @LogActionId_Upd
		) A
		LEFT JOIN dbo.UserInfo u1 WITH(NOLOCK) ON A.UserId = u1.UserId
		WHERE A.RowNumber = 1
	), CTE_Create AS (
		SELECT u2.DisplayName, B.LogDate, B.ContactId FROM (
			SELECT ROW_NUMBER() OVER(PARTITION BY ContactId ORDER BY Id DESC) AS RowNumber
					, UserId, LogDate, ContactId
			FROM #LogContact
			WHERE LogActionId = @LogActionId_Ins
		) B
		LEFT JOIN dbo.UserInfo u2 WITH(NOLOCK) ON B.UserId = u2.UserId
		WHERE B.RowNumber = 1
	)
	
	SELECT	r.ContactID
			,ContactName
			,ContactType
			,Position
			,Department
			,PhoneNumber
			,Email
			,Skype
			,Landline
			,Remark
			,ToList
			,CcList
			,IsMain
			,c.LogDate AS Created
			,u.LogDate AS Updated
			,ISNULL(u.DisplayName, c.DisplayName) AS [By]
	FROM	#tblResult r
		LEFT JOIN CTE_Update u ON r.ContactID = u.ContactId
		LEFT JOIN CTE_Create c ON r.ContactID = c.ContactId
	WHERE	RowNumber BETWEEN @RowStart AND @RowEnd
    
	DROP TABLE #tblResult
	DROP TABLE #LogContact

END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeContactListSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeContactListSel_xtest    Script Date: 9/29/2016 1:04:12 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeContactListSel_xtest    Script Date: 9/29/2016 8:37:11 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeContactListSel_xtest]
    @UserId        INT
    ,@LicenseeName NVARCHAR(50)
    ,@ContactName  NVARCHAR(50)    = ''
    
    ,@PageSize			INT = 10
	,@PageIndex			INT	= 0 
	,@TotalRecords		INT = 0 OUTPUT
AS
/*
    Created by: Kathy
    Date: 2015-02-04
    Task: Licensee contact list [Redmine:#29610]
    DB: DBOIC/BODB_OIC 
    
    Revisions:
		- 20160920@Percy: Add new return field: Change History [RedmineID: #]
    
    Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON
    
    DECLARE @tblContactList TABLE(ContactId INT)
    DECLARE @ToList		VARCHAR(1000)
			,@CcList	VARCHAR(1000)
			,@RowCount	INT	
			,@RowStart	INT
			,@RowEnd	INT
    
    INSERT INTO @tblContactList(ContactId)
    SELECT	c.ContactID    
    FROM	dbo.Contact c WITH(NOLOCK)
		INNER JOIN dbo.Licensee l WITH(NOLOCK) 
			ON	c.LicenseeID = l.LicenseeId
    WHERE	l.LicenseeTypeId IN (SELECT		u.LicenseeTypeId 
									FROM	dbo.UserLicenseeType u WITH(NOLOCK) 
									WHERE	u.UserId = @UserId)
			AND l.LicenseeName = @LicenseeName
			AND c.ContactName LIKE @ContactName + '%'    
    
    -- General info
    SELECT ROW_NUMBER() OVER (ORDER BY lc.IsMain DESC, lc.ContactName) AS RowNumber
			,lc.ContactID
			,lc.ContactName
			,lc.ContactType 
			,lc.ContactPosition		AS Position
			,lc.ContactDepartment	AS Department
			,lc.ContactPhoneNumber	AS PhoneNumber
			,lc.ContactEmail		AS Email
			,lc.ContactSkype		AS Skype
			,lc.ContactLandline		AS Landline
			,lc.Remark
			,(SELECT ISNULL(@ToList,'') + c.CategoryName + ','  
				FROM dbo.CategoryContact cc WITH(NOLOCK)
					INNER JOIN dbo.Category c WITH(NOLOCK) 
						ON c.CategoryId = cc.CategoryID
				WHERE cc.ContactID = lc.ContactID 
						AND cc.RecipientType = 0 
				FOR XML PATH('')
			  ) AS ToList
			,(SELECT ISNULL(@CcList,'') + c.CategoryName + ','  
				FROM dbo.CategoryContact cc WITH(NOLOCK)
					INNER JOIN dbo.Category c WITH(NOLOCK) 
						ON c.CategoryId = cc.CategoryID
				WHERE cc.ContactID = lc.ContactID 
						AND cc.RecipientType = 1
			   FOR XML PATH('')
			  ) AS CcList
			 ,lc.IsMain
    INTO	#tblResult
    FROM	dbo.Contact lc WITH(NOLOCK)
    WHERE	lc.ContactID IN (SELECT ContactID FROM @tblContactList)
    
	SELECT @PageIndex	= @PageIndex ,
		@RowStart		= @PageSize * @PageIndex + 1
		,@RowEnd		= @RowStart + @PageSize - 1
	
	IF @TotalRecords = 0
	BEGIN
		SELECT	@TotalRecords	= COUNT(1)
		FROM	#tblResult
	END

	-- Get log latest update contact --
	DECLARE @LogActionId_Ins INT, @LogActionId_Upd INT

	SELECT  @LogActionId_Ins = LogActionId FROM dbo.LogAction WITH(NOLOCK) WHERE SPName = 'OIC_LicenseeContactIns'
	SELECT  @LogActionId_Upd = LogActionId FROM dbo.LogAction WITH(NOLOCK) WHERE SPName = 'OIC_LicenseeContactUpd'

	CREATE TABLE #LogContact (Id BIGINT PRIMARY KEY, LogActionId INT, UserId INT, LogDate DATETIME, ContactId INT)
	INSERT INTO  #LogContact (Id, LogActionId, UserId, LogDate, ContactId)
	SELECT
		A.Id, A.LogActionId, A.UserId, A.LogDate,
		d.c.value('@lcid','INT') AS ContactId -- ContactId
	FROM (
		SELECT u.Id, u.LogActionId, u.UserId, u.LogDate, CONVERT(XML, ud.Data) AS Data
		FROM dbo.UserLog_RunSP u WITH(NOLOCK)
			INNER JOIN dbo.UserLog_RunSP_Detail ud WITH(NOLOCK) ON u.Id = ud.Id
		WHERE u.LogActionId IN (@LogActionId_Ins, @LogActionId_Upd)
	) AS A
	CROSS APPLY A.Data.nodes('r') d(c)
	-- End get log --

	CREATE NONCLUSTERED INDEX IX_ContactId ON #LogContact (ContactId, LogActionId)

	;WITH CTE_Update AS (
		SELECT u1.DisplayName, A.LogDate, A.ContactId FROM (
			SELECT ROW_NUMBER() OVER(PARTITION BY ContactId ORDER BY Id DESC) AS RowNumber
					, UserId, LogDate, ContactId
			FROM #LogContact
			WHERE LogActionId = @LogActionId_Upd
		) A
		LEFT JOIN dbo.UserInfo u1 WITH(NOLOCK) ON A.UserId = u1.UserId
		WHERE A.RowNumber = 1
	), CTE_Create AS (
		SELECT u2.DisplayName, B.LogDate, B.ContactId FROM (
			SELECT ROW_NUMBER() OVER(PARTITION BY ContactId ORDER BY Id DESC) AS RowNumber
					, UserId, LogDate, ContactId
			FROM #LogContact
			WHERE LogActionId = @LogActionId_Ins
		) B
		LEFT JOIN dbo.UserInfo u2 WITH(NOLOCK) ON B.UserId = u2.UserId
		WHERE B.RowNumber = 1
	)
	
	SELECT	r.ContactID
			,ContactName
			,ContactType
			,Position
			,Department
			,PhoneNumber
			,Email
			,Skype
			,Landline
			,Remark
			,ToList
			,CcList
			,IsMain
			,c.LogDate AS Created
			,u.LogDate AS Updated
			,ISNULL(u.DisplayName, c.DisplayName) AS [By]
	FROM	#tblResult r
		LEFT JOIN CTE_Update u ON r.ContactID = u.ContactId
		LEFT JOIN CTE_Create c ON r.ContactID = c.ContactId
	WHERE	RowNumber BETWEEN @RowStart AND @RowEnd
    
	DROP TABLE #tblResult
	DROP TABLE #LogContact

END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeContactSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeContactSel    Script Date: 16/04/2015 9:22:41 AM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeContactSel_xtest    Script Date: 10/04/2015 1:36:57 PM ******/
CREATE PROCEDURE [dbo].[OIC_LicenseeContactSel]
	@ContactId		INT
AS
/*
	Created by: Kathy
	Date: 2015-02-09
	Task: Licensee contact info [Redmine:#30037]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	Param's Explanation:
	*
*/
BEGIN
	SET NOCOUNT ON

	SELECT	c.ContactID
			,l.LicenseeId
			,l.LicenseeTypeId
			,c.ContactType
			,c.ContactName
			,c.ContactPosition AS Position
			,c.ContactDepartment AS Department
			,c.ContactEmail AS Email
			,c.ContactSkype AS Skype
			,c.ContactPhoneNumber AS PhoneNumber
			,c.ContactLandline AS Landline
			,c.Remark
	FROM dbo.Contact c WITH(NOLOCK)
		INNER JOIN dbo.Licensee l WITH(NOLOCK) 
			ON	c.LicenseeID = l.LicenseeId
	WHERE	c.ContactID = @ContactId
	
	SELECT	CategoryID
			,RecipientType as Type
	FROM dbo.CategoryContact WITH(NOLOCK)
	WHERE ContactID = @ContactId
	
END


GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeContactUpd]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeContactUpd    Script Date: 11/21/2016 10:54:00 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeContactUpd    Script Date: 11/11/2016 10:29:58 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeContactUpd]
	@ContactId				INT
	,@LicenseeId			INT
	,@ContactType			BIT
	,@ContactName			NVARCHAR(50)
	,@Position				NVARCHAR(50)
	,@Department			NVARCHAR(50) 
	,@Email					VARCHAR(50)
	,@Skype					VARCHAR(50)
	,@PhoneNumber			VARCHAR(50)		= NULL
	,@LandLine				VARCHAR(50)		= NULL
	,@Remark				NVARCHAR(300)	= NULL
	
	,@SelectedCategories	XML				= NULL 
	
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2015-02-09
	Task: Update licensee contact [Redmine:#30037]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	Param's Explanation:
	- @SelectedCategories: NULL: no changing
							<> NULL: changed data
*/
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPOldData	NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
		
		,@log_category	XML
	
	DECLARE @tblCategoryContact TABLE (CategoryId INT, RecipientType TINYINT)

	SET @startRun = GETDATE()			
	
	-- get data to write log before doing	
	IF @SelectedCategories IS NOT NULL
	BEGIN
		SET @log_category = (
							SELECT	c.CategoryName		AS '@cn'
									,cc.RecipientType	AS '@ct'
							FROM	dbo.Category AS c WITH (NOLOCK)
								INNER JOIN dbo.CategoryContact AS cc WITH(NOLOCK) 
									ON	c.CategoryId = cc.CategoryID
							WHERE	cc.ContactID = @ContactId
							FOR XML PATH('row'), ROOT('cc')	
						)
	END
					
	SET @xml = (
		SELECT	@ContactId				AS '@lcid'
				,LicenseeId				AS '@lid'
				,c.ContactName			AS '@lccn'			
				,c.ContactPosition		AS '@lcp'
				,c.ContactDepartment	AS '@lcd'
				,c.ContactEmail			AS '@lce'
				,c.ContactSkype			AS '@lcs'
				,c.ContactPhoneNumber	AS '@lcpn'
				,c.ContactLandline		AS '@lcll'
				,c.ContactType			AS '@lcct'
				,c.Remark				AS '@lcr'
				,@log_category
		FROM dbo.Contact AS c WITH (NOLOCK)
		WHERE c.ContactID = @ContactId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPOldData = CONVERT(NVARCHAR(MAX),@xml)
	
	BEGIN TRY
		UPDATE	dbo.Contact WITH(ROWLOCK, UPDLOCK)
			SET LicenseeID			= @LicenseeId
				,ContactType		= @ContactType
				,ContactName		= @ContactName
				,ContactPosition	= @Position
				,ContactDepartment	= @Department
				,ContactEmail		= @Email
				,ContactSkype		= @Skype
				,ContactPhoneNumber	= @PhoneNumber
				,ContactLandline	= @Landline
				,Remark				= @Remark
		WHERE	ContactID = @ContactId
		
		IF @SelectedCategories IS NOT NULL
		BEGIN
		
			;WITH selectedCategory
			AS (
				SELECT	t.c.value('@id','int') CategoryId
						,t.c.value('@type', 'bit') AS Value
				FROM	@SelectedCategories.nodes('root/row') t(c)
			)
			INSERT INTO @tblCategoryContact (
					CategoryID
					,RecipientType
			)
			SELECT	s.CategoryId
					,s.Value
			FROM	selectedCategory s 
				INNER JOIN dbo.LicenseeCategoryAssigned l WITH(NOLOCK)
					ON	s.CategoryId = l. CategoryId
						AND l.LicenseeId = @LicenseeId					
			
			MERGE	dbo.CategoryContact c
			USING	(SELECT * FROM @tblCategoryContact) t
				ON	c.CategoryID = t.CategoryId
					AND c.ContactID = @ContactId
			WHEN MATCHED AND c.RecipientType <> t.RecipientType THEN UPDATE SET c.RecipientType = t.RecipientType
			WHEN NOT MATCHED BY TARGET THEN INSERT (ContactID, CategoryID, RecipientType) VALUES (@ContactId, t.CategoryId, t.RecipientType)
			WHEN NOT MATCHED BY SOURCE AND c.ContactId = @ContactId THEN DELETE;
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](501,@Language) -- Failed to edit contact. Please try again!		
		RETURN
	END CATCH	
	
	-- Write log
	-- get data to write log
	IF @SelectedCategories IS NOT NULL
	BEGIN
		SET @log_category = (
							SELECT	c.CategoryName		AS '@cn'
									,cc.RecipientType	AS '@ct'
							FROM	dbo.Category AS c WITH (NOLOCK)
								INNER JOIN dbo.CategoryContact AS cc WITH(NOLOCK) 
									ON	c.CategoryId = cc.CategoryID
							WHERE	cc.ContactID = @ContactId
							FOR XML PATH('row'), ROOT('cc')	
						)
	END
					
	SET @xml = (
		SELECT	@ContactId				AS '@lcid'
				,LicenseeId				AS '@lid'
				,c.ContactName			AS '@lccn'			
				,c.ContactPosition		AS '@lcp'
				,c.ContactDepartment	AS '@lcd'
				,c.ContactEmail			AS '@lce'
				,c.ContactSkype			AS '@lcs'
				,c.ContactPhoneNumber	AS '@lcpn'
				,c.ContactLandline		AS '@lcll'
				,c.ContactType			AS '@lcct'
				,c.Remark				AS '@lcr'
				,@log_category
		FROM dbo.Contact AS c WITH (NOLOCK)
		WHERE c.ContactID = @ContactId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

		EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOldData
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeContactUpd_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeContactUpd_xtest    Script Date: 11/11/2016 10:29:58 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeContactUpd_xtest]
	@ContactId				INT
	,@LicenseeId			INT
	,@ContactType			BIT
	,@ContactName			NVARCHAR(50)
	,@Position				NVARCHAR(50)
	,@Department			NVARCHAR(50) 
	,@Email					VARCHAR(50)
	,@Skype					VARCHAR(50)
	,@PhoneNumber			VARCHAR(50)		= NULL
	,@LandLine				VARCHAR(50)		= NULL
	,@Remark				NVARCHAR(300)	= NULL
	
	,@SelectedCategories	XML				= NULL 
	
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2015-02-09
	Task: Update licensee contact [Redmine:#30037]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	Param's Explanation:
	- @SelectedCategories: NULL: no changing
							<> NULL: changed data
*/
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPOldData	NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
		
		,@log_category	XML
	
	DECLARE @tblCategoryContact TABLE (CategoryId INT, RecipientType TINYINT)

	SET @startRun = GETDATE()			
	
	-- get data to write log before doing	
	IF @SelectedCategories IS NOT NULL
	BEGIN
		SET @log_category = (
							SELECT	c.CategoryName		AS '@cn'
									,cc.RecipientType	AS '@ct'
							FROM	dbo.Category AS c WITH (NOLOCK)
								INNER JOIN dbo.CategoryContact AS cc WITH(NOLOCK) 
									ON	c.CategoryId = cc.CategoryID
							WHERE	cc.ContactID = @ContactId
							FOR XML PATH('row'), ROOT('cc')	
						)
	END
					
	SET @xml = (
		SELECT	@ContactId				AS '@lcid'
				,LicenseeId				AS '@lid'
				,c.ContactName			AS '@lccn'			
				,c.ContactPosition		AS '@lcp'
				,c.ContactDepartment	AS '@lcd'
				,c.ContactEmail			AS '@lce'
				,c.ContactSkype			AS '@lcs'
				,c.ContactPhoneNumber	AS '@lcpn'
				,c.ContactLandline		AS '@lcll'
				,c.ContactType			AS '@lcct'
				,c.Remark				AS '@lcr'
				,@log_category
		FROM dbo.Contact AS c WITH (NOLOCK)
		WHERE c.ContactID = @ContactId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPOldData = CONVERT(NVARCHAR(MAX),@xml)
	
	BEGIN TRY
		UPDATE	dbo.Contact WITH(ROWLOCK, UPDLOCK)
			SET LicenseeID			= @LicenseeId
				,ContactType		= @ContactType
				,ContactName		= @ContactName
				,ContactPosition	= @Position
				,ContactDepartment	= @Department
				,ContactEmail		= @Email
				,ContactSkype		= @Skype
				,ContactPhoneNumber	= @PhoneNumber
				,ContactLandline	= @Landline
				,Remark				= @Remark
		WHERE	ContactID = @ContactId
		
		IF @SelectedCategories IS NOT NULL
		BEGIN
		
			;WITH selectedCategory
			AS (
				SELECT	t.c.value('@id','int') CategoryId
						,t.c.value('@type', 'bit') AS Value
				FROM	@SelectedCategories.nodes('root/row') t(c)
			)
			INSERT INTO @tblCategoryContact (
					CategoryID
					,RecipientType
			)
			SELECT	s.CategoryId
					,s.Value
			FROM	selectedCategory s 
				INNER JOIN dbo.LicenseeCategoryAssigned l WITH(NOLOCK)
					ON	s.CategoryId = l. CategoryId
						AND l.LicenseeId = @LicenseeId					
			
			MERGE	dbo.CategoryContact c
			USING	(SELECT * FROM @tblCategoryContact) t
				ON	c.CategoryID = t.CategoryId
					AND c.ContactID = @ContactId
			WHEN MATCHED AND c.RecipientType <> t.RecipientType THEN UPDATE SET c.RecipientType = t.RecipientType
			WHEN NOT MATCHED BY TARGET THEN INSERT (ContactID, CategoryID, RecipientType) VALUES (@ContactId, t.CategoryId, t.RecipientType)
			WHEN NOT MATCHED BY SOURCE AND c.ContactId = @ContactId THEN DELETE;
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](501,@Language) -- Failed to edit contact. Please try again!		
		RETURN
	END CATCH	
	
	-- Write log
	-- get data to write log
	IF @SelectedCategories IS NOT NULL
	BEGIN
		SET @log_category = (
							SELECT	c.CategoryName		AS '@cn'
									,cc.RecipientType	AS '@ct'
							FROM	dbo.Category AS c WITH (NOLOCK)
								INNER JOIN dbo.CategoryContact AS cc WITH(NOLOCK) 
									ON	c.CategoryId = cc.CategoryID
							WHERE	cc.ContactID = @ContactId
							FOR XML PATH('row'), ROOT('cc')	
						)
	END
					
	SET @xml = (
		SELECT	@ContactId				AS '@lcid'
				,LicenseeId				AS '@lid'
				,c.ContactName			AS '@lccn'			
				,c.ContactPosition		AS '@lcp'
				,c.ContactDepartment	AS '@lcd'
				,c.ContactEmail			AS '@lce'
				,c.ContactSkype			AS '@lcs'
				,c.ContactPhoneNumber	AS '@lcpn'
				,c.ContactLandline		AS '@lcll'
				,c.ContactType			AS '@lcct'
				,c.Remark				AS '@lcr'
				,@log_category
		FROM dbo.Contact AS c WITH (NOLOCK)
		WHERE c.ContactID = @ContactId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOldData
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeFeatureByFeatureSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeFeatureByFeatureSel    Script Date: 5/3/2017 10:41:17 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeFeatureByFeatureSel    Script Date: 4/24/2017 10:21:28 AM ******/
/*<info serverAlias="DBOIC-bodb_OIC" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[OIC_LicenseeFeatureByFeatureSel]
	@FeatureId			TINYINT
	,@UserId			INT
AS

/*
	Created by: Percy
	Date: 2017-03-28
	Task: Select Client Feature [RedmineID: #70323]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	Param's Explanation:

*/

BEGIN
	SET NOCOUNT ON
	
	SELECT	l.LicenseeId
			,l.LicenseeName
			,lp.LaunchDate
			,lp.TerminationDate
	FROM dbo.Licensee l WITH(NOLOCK)
		LEFT JOIN dbo.LicenseeFeature lp WITH(NOLOCK) 
			ON	l.LicenseeId = lp.LicenseeId 
				AND lp.FeatureId = @FeatureId
	WHERE l.LicenseeTypeId IN (SELECT LicenseeTypeId FROM dbo.UserLicenseeType WITH(NOLOCK) WHERE UserId = @UserId)
	ORDER BY l.LicenseeName
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeFeatureByFeatureSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeFeatureByFeatureSel_xtest    Script Date: 4/24/2017 10:21:28 AM ******/
/*<info serverAlias="DBOIC-bodb_OIC" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[OIC_LicenseeFeatureByFeatureSel_xtest]
	@FeatureId			TINYINT
	,@UserId			INT
AS

/*
	Created by: Percy
	Date: 2017-03-28
	Task: Select Client Feature [RedmineID: #70323]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	Param's Explanation:

*/

BEGIN
	SET NOCOUNT ON
	
	SELECT	l.LicenseeId
			,l.LicenseeName
			,lp.LaunchDate
			,lp.TerminationDate
	FROM dbo.Licensee l WITH(NOLOCK)
		LEFT JOIN dbo.LicenseeFeature lp WITH(NOLOCK) 
			ON	l.LicenseeId = lp.LicenseeId 
				AND lp.FeatureId = @FeatureId
	WHERE l.LicenseeTypeId IN (SELECT LicenseeTypeId FROM dbo.UserLicenseeType WITH(NOLOCK) WHERE UserId = @UserId)
	ORDER BY l.LicenseeName
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeFeatureByFeatureUpd]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeFeatureByFeatureUpd    Script Date: 5/3/2017 10:41:15 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeFeatureByFeatureUpd    Script Date: 4/24/2017 10:21:28 AM ******/
/*<info serverAlias="DBOIC-bodb_OIC" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[OIC_LicenseeFeatureByFeatureUpd]
    @FeatureId          TINYINT,
    @SelectedLicensee   XML					= NULL,
    @UserId             INT,
    @Language           VARCHAR(10)			= 'E',
    @IP                 VARCHAR(50)			= NULL,
    @ErrCode            INT					= 0     OUTPUT,
    @ErrMsg             VARCHAR(300)		= NULL  OUTPUT
AS

/*
    Created by: Percy
    Date: 2017-03-28
    Task: Update Client feature by feature [RedmineID: #70323]
    DB: DBOIC.bodb_OIC
    
    Revisions:
    
    Param's Explanation:
    - @SelectedLicensee: list of licensee                    
        <root>
            <row LicenseeId="1" launchdate="2014-12-19" terminationdate="2016-05-13"/>
            <row LicenseeId="3" launchdate="2014-12-19"/>
        </root> 
*/

BEGIN
    SET NOCOUNT ON
    
    -- For write log
    DECLARE 
        @startRun       DATETIME
        ,@endRun        DATETIME
        ,@duration      INT
        ,@logSPData     NVARCHAR(MAX)
        ,@logSPOlddata  NVARCHAR(MAX)    
        ,@xml           XML
        ,@procName      VARCHAR(200)
        ,@FeatureName   VARCHAR(50)

		,@tempStartRun	DATETIME
		,@tempEndRun	DATETIME
    
    SET @startRun = GETDATE()
    
    DECLARE @tblLicenseeoffered TABLE (LicenseeId INT, LaunchDate DATETIME, TerminationDate DATETIME, IsDelete BIT DEFAULT 0)
	DECLARE @tblLicenseebefore TABLE (LicenseeId INT, LaunchDate DATETIME, TerminationDate DATETIME, IsDelete BIT DEFAULT 0)
    
    SELECT @FeatureName = FeatureName 
    FROM dbo.Feature WITH(NOLOCK) 
    WHERE FeatureId = @FeatureId
    
    IF @@ROWCOUNT = 0
    BEGIN
        SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30000, @Language) -- Feature does not exist.
        RETURN
    END
    
    INSERT INTO @tblLicenseeoffered (LicenseeId, LaunchDate, TerminationDate)
    SELECT	t.c.value('@LicenseeId','int') AS LicenseeId
			,t.c.value('@launchdate', 'datetime') AS LaunchDate
			,t.c.value('@terminationdate', 'datetime') AS TerminationDate
    FROM @SelectedLicensee.nodes('root/row') t(c)

	INSERT INTO @tblLicenseebefore (LicenseeId, LaunchDate, TerminationDate)
	SELECT	l.LicenseeId, lf.LaunchDate, lf.TerminationDate
	FROM dbo.Licensee l WITH (NOLOCK)
		INNER JOIN dbo.LicenseeFeature lf WITH(NOLOCK) ON l.LicenseeId = lf.LicenseeId 
	WHERE lf.FeatureId = @FeatureId
    
    IF @@ERROR <> 0
    BEGIN
        SELECT	@ErrCode = 102
                ,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](2000, @Language) -- Fail to edit feature's clients. Please try again.
        RETURN
    END
    
    -- get data before update/insert
    SET @xml = (SELECT	@FeatureId AS '@fid'
						,@FeatureName AS '@fn'
						,(SELECT	l.LicenseeId AS '@lid'
									,l.LicenseeName AS '@ln'
									,lf.LaunchDate AS '@lfld'
									,lf.TerminationDate AS '@lftd'
							FROM dbo.Licensee l WITH (NOLOCK)
								INNER JOIN dbo.LicenseeFeature lf WITH(NOLOCK) ON l.LicenseeId = lf.LicenseeId 
							WHERE lf.FeatureId = @FeatureId
							FOR XML PATH('row'), TYPE, ROOT('lf'))
				FOR XML PATH('r')
	)

    SELECT @logSPOldData = CONVERT(NVARCHAR(MAX),@xml)
    
    BEGIN TRY
		MERGE dbo.LicenseeFeature lf
		USING (SELECT LicenseeId, LaunchDate, TerminationDate FROM @tblLicenseeoffered) AS t
			ON	(lf.LicenseeId = t.LicenseeId AND lf.FeatureId = @FeatureId)
		WHEN MATCHED AND (lf.LaunchDate <> t.LaunchDate OR ISNULL(lf.TerminationDate, '') <> ISNULL(t.TerminationDate, '')) THEN UPDATE SET lf.LaunchDate = t.LaunchDate, lf.TerminationDate = t.TerminationDate
		WHEN NOT MATCHED BY TARGET THEN INSERT (LicenseeId, FeatureId, LaunchDate, TerminationDate) VALUES (t.LicenseeId, @FeatureId, t.LaunchDate, t.TerminationDate);
		
		DELETE	dbo.LicenseeFeature WITH(ROWLOCK, UPDLOCK)
		WHERE	FeatureId = @FeatureId
				AND LicenseeId NOT IN (SELECT LicenseeId FROM @tblLicenseeoffered)
				
    END TRY
    BEGIN CATCH
        SELECT	@ErrCode = 103
                ,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](2000, @Language) + ERROR_MESSAGE() -- Fail to edit feature's clients. Please try again.
        RETURN
    END CATCH        

    -- Write log
    SET @xml = (SELECT	@FeatureId AS '@fid'
						,@FeatureName AS '@fn'
						,(SELECT	l.LicenseeId AS '@lid'
									,l.LicenseeName AS '@ln'
									,lf.LaunchDate AS '@lfld'
									,lf.TerminationDate AS '@lftd'
							FROM dbo.Licensee l WITH (NOLOCK)
								INNER JOIN dbo.LicenseeFeature lf WITH(NOLOCK) ON l.LicenseeId = lf.LicenseeId 
							WHERE
								l.LicenseeId IN (SELECT LicenseeId FROM @tblLicenseeoffered)
								AND lf.FeatureId = @FeatureId
							FOR XML PATH('row'), TYPE, ROOT('lf'))
				FOR XML PATH('r')
	)       
        
    SELECT @logSPData = CONVERT(NVARCHAR(MAX),@xml)
        ,@endRun    = GETDATE()  
        ,@duration    = DATEDIFF(MILLISECOND, @startRun, @endRun)   
        ,@procName    = OBJECT_NAME(@@PROCID)
    
        EXEC dbo.OIC_LogRunSpIns
		@UserId         = @UserId
		,@SPName        = @procName
		,@Language      = @Language
		,@IP            = @IP
		,@Data          = @logSPData
		,@OldData       = @logSPOlddata
		,@Duration      = @Duration

	DECLARE @Licensee TABLE (LicenseeId INT, LaunchDate DATETIME, TerminationDate DATETIME)
	DECLARE @LicenseeId INT

	SELECT  @procName = SPName, @tempEndRun = GETDATE() FROM dbo.LogAction WITH(NOLOCK) WHERE LogActionId = 501 -- write log for client

	UPDATE b
	SET b.IsDelete = 1
	FROM @tblLicenseebefore b
		INNER JOIN @tblLicenseeoffered a ON b.LicenseeId = a.LicenseeId
	WHERE ISNULL(b.LaunchDate, CONVERT(DATETIME, '19700101')) = ISNULL(a.LaunchDate, CONVERT(DATETIME, '19700101'))
		AND ISNULL(b.TerminationDate, CONVERT(DATETIME, '19700101')) = ISNULL(a.TerminationDate, CONVERT(DATETIME, '19700101'))

	UPDATE a
	SET a.IsDelete = 1
	FROM @tblLicenseebefore b
		INNER JOIN @tblLicenseeoffered a ON b.LicenseeId = a.LicenseeId
	WHERE ISNULL(b.LaunchDate, CONVERT(DATETIME, '19700101')) = ISNULL(a.LaunchDate, CONVERT(DATETIME, '19700101'))
		AND ISNULL(b.TerminationDate, CONVERT(DATETIME, '19700101')) = ISNULL(a.TerminationDate, CONVERT(DATETIME, '19700101'))

	DELETE @tblLicenseebefore WHERE IsDelete = 1
	DELETE @tblLicenseeoffered WHERE IsDelete = 1

	WHILE 1=1
	BEGIN
		SELECT @tempStartRun = GETDATE(), @LicenseeId = NULL, @logSPData = NULL, @logSPOlddata = NULL
		
		IF EXISTS (SELECT TOP 1 1 FROM @tblLicenseebefore)
		BEGIN
			SELECT TOP 1 @LicenseeId = LicenseeId FROM @tblLicenseebefore ORDER BY LicenseeId

			DELETE @Licensee
			DELETE @tblLicenseebefore OUTPUT DELETED.LicenseeId, DELETED.LaunchDate, DELETED.TerminationDate INTO @Licensee WHERE LicenseeId = @LicenseeId

			SET @xml = (SELECT	l.LicenseeId		AS '@lid'
								,l.LicenseeName		AS '@ln'
								,(
								SELECT	FeatureId			AS '@fid'
											,FeatureName		AS '@fn'
											,LaunchDate			AS '@lld'
											,TerminationDate	AS '@ltd'
								FROM (
									SELECT	@FeatureId AS FeatureId, @FeatureName AS FeatureName, LaunchDate, TerminationDate
									FROM @Licensee
									UNION ALL
									SELECT	f.FeatureId, FeatureName, LaunchDate, TerminationDate
									FROM LicenseeFeature lf WITH(NOLOCK)
										INNER JOIN Feature f WITH(NOLOCK) ON lf.FeatureId = f.FeatureId AND lf.LicenseeId = @LicenseeId
									WHERE f.FeatureId <> @FeatureId
								) AS A
								ORDER BY FeatureId
								FOR XML PATH('row'), ROOT('lf'), TYPE)
						FROM dbo.Licensee l WITH(NOLOCK)
						WHERE l.LicenseeId = @LicenseeId
						FOR XML PATH('r'), TYPE
			)
			SELECT @logSPOlddata = CONVERT(NVARCHAR(MAX), @xml)

			BEGIN
				DELETE @tblLicenseeoffered WHERE LicenseeId = @LicenseeId

				SET @xml = (SELECT	l.LicenseeId		AS '@lid'
									,l.LicenseeName		AS '@ln'
									,(SELECT	f.FeatureId AS '@fid', FeatureName AS '@fn', LaunchDate AS '@lld', TerminationDate AS '@ltd'
									FROM LicenseeFeature lf WITH(NOLOCK)
										INNER JOIN Feature f WITH(NOLOCK) ON lf.FeatureId = f.FeatureId AND lf.LicenseeId = @LicenseeId
									ORDER BY lf.FeatureId
									FOR XML PATH('row'), ROOT('lf'), TYPE)
							FROM dbo.Licensee l WITH(NOLOCK)
							WHERE l.LicenseeId = @LicenseeId
							FOR XML PATH('r'), TYPE
				)
				SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
			END
		END
		ELSE IF EXISTS (SELECT TOP 1 1 FROM @tblLicenseeoffered)
		BEGIN
			SELECT TOP 1 @LicenseeId = LicenseeId FROM @tblLicenseeoffered ORDER BY LicenseeId

			DELETE @tblLicenseeoffered WHERE LicenseeId = @LicenseeId

			SET @xml = (SELECT	l.LicenseeId		AS '@lid'
								,l.LicenseeName		AS '@ln'
								,(SELECT	f.FeatureId AS '@fid', FeatureName AS '@fn', LaunchDate AS '@lld', TerminationDate AS '@ltd'
								FROM LicenseeFeature lf WITH(NOLOCK)
									INNER JOIN Feature f WITH(NOLOCK) ON lf.FeatureId = f.FeatureId AND lf.LicenseeId = @LicenseeId
								WHERE f.FeatureId <> @FeatureId
								ORDER BY f.FeatureId
								FOR XML PATH('row'), ROOT('lf'), TYPE)
						FROM dbo.Licensee l WITH(NOLOCK)
						WHERE l.LicenseeId = @LicenseeId
						FOR XML PATH('r'), TYPE
			)
			SELECT @logSPOlddata = CONVERT(NVARCHAR(MAX), @xml)
			
			SET @xml = (SELECT	l.LicenseeId		AS '@lid'
								,l.LicenseeName		AS '@ln'
								,(SELECT	f.FeatureId AS '@fid', FeatureName AS '@fn', LaunchDate AS '@lld', TerminationDate AS '@ltd'
								FROM LicenseeFeature lf WITH(NOLOCK)
									INNER JOIN Feature f WITH(NOLOCK) ON lf.FeatureId = f.FeatureId AND lf.LicenseeId = @LicenseeId
								ORDER BY f.FeatureId
								FOR XML PATH('row'), ROOT('lf'), TYPE)
						FROM dbo.Licensee l WITH(NOLOCK)
						WHERE l.LicenseeId = @LicenseeId
						FOR XML PATH('r'), TYPE
			)
			SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		END
		ELSE
			BREAK

		SELECT	@endRun		= GETDATE()  
				,@duration	= DATEDIFF(MILLISECOND, @startRun, @tempEndRun) + DATEDIFF(MILLISECOND, @tempStartRun, @endRun)

				EXEC dbo.OIC_LogRunSpIns
			@UserId			= @UserId
			,@SPName		= @procName
			,@Language		= @Language
			,@IP			= @IP
			,@Data          = @logSPData
			,@OldData       = @logSPOlddata
			,@Duration		= @Duration
	END
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeFeatureByFeatureUpd_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeFeatureByFeatureUpd_xtest    Script Date: 4/24/2017 10:21:28 AM ******/
/*<info serverAlias="DBOIC-bodb_OIC" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[OIC_LicenseeFeatureByFeatureUpd_xtest]
    @FeatureId          TINYINT,
    @SelectedLicensee   XML					= NULL,
    @UserId             INT,
    @Language           VARCHAR(10)			= 'E',
    @IP                 VARCHAR(50)			= NULL,
    @ErrCode            INT					= 0     OUTPUT,
    @ErrMsg             VARCHAR(300)		= NULL  OUTPUT
AS

/*
    Created by: Percy
    Date: 2017-03-28
    Task: Update Client feature by feature [RedmineID: #70323]
    DB: DBOIC.bodb_OIC
    
    Revisions:
    
    Param's Explanation:
    - @SelectedLicensee: list of licensee                    
        <root>
            <row LicenseeId="1" launchdate="2014-12-19" terminationdate="2016-05-13"/>
            <row LicenseeId="3" launchdate="2014-12-19"/>
        </root> 
*/

BEGIN
    SET NOCOUNT ON
    
    -- For write log
    DECLARE 
        @startRun       DATETIME
        ,@endRun        DATETIME
        ,@duration      INT
        ,@logSPData     NVARCHAR(MAX)
        ,@logSPOlddata  NVARCHAR(MAX)    
        ,@xml           XML
        ,@procName      VARCHAR(200)
        ,@FeatureName   VARCHAR(50)

		,@tempStartRun	DATETIME
		,@tempEndRun	DATETIME
    
    SET @startRun = GETDATE()
    
    DECLARE @tblLicenseeoffered TABLE (LicenseeId INT, LaunchDate DATETIME, TerminationDate DATETIME, IsDelete BIT DEFAULT 0)
	DECLARE @tblLicenseebefore TABLE (LicenseeId INT, LaunchDate DATETIME, TerminationDate DATETIME, IsDelete BIT DEFAULT 0)
    
    SELECT @FeatureName = FeatureName 
    FROM dbo.Feature WITH(NOLOCK) 
    WHERE FeatureId = @FeatureId
    
    IF @@ROWCOUNT = 0
    BEGIN
        SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30000, @Language) -- Feature does not exist.
        RETURN
    END
    
    INSERT INTO @tblLicenseeoffered (LicenseeId, LaunchDate, TerminationDate)
    SELECT	t.c.value('@LicenseeId','int') AS LicenseeId
			,t.c.value('@launchdate', 'datetime') AS LaunchDate
			,t.c.value('@terminationdate', 'datetime') AS TerminationDate
    FROM @SelectedLicensee.nodes('root/row') t(c)

	INSERT INTO @tblLicenseebefore (LicenseeId, LaunchDate, TerminationDate)
	SELECT	l.LicenseeId, lf.LaunchDate, lf.TerminationDate
	FROM dbo.Licensee l WITH (NOLOCK)
		INNER JOIN dbo.LicenseeFeature lf WITH(NOLOCK) ON l.LicenseeId = lf.LicenseeId 
	WHERE lf.FeatureId = @FeatureId
    
    IF @@ERROR <> 0
    BEGIN
        SELECT	@ErrCode = 102
                ,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](2000, @Language) -- Fail to edit feature's clients. Please try again.
        RETURN
    END
    
    -- get data before update/insert
    SET @xml = (SELECT	@FeatureId AS '@fid'
						,@FeatureName AS '@fn'
						,(SELECT	l.LicenseeId AS '@lid'
									,l.LicenseeName AS '@ln'
									,lf.LaunchDate AS '@lfld'
									,lf.TerminationDate AS '@lftd'
							FROM dbo.Licensee l WITH (NOLOCK)
								INNER JOIN dbo.LicenseeFeature lf WITH(NOLOCK) ON l.LicenseeId = lf.LicenseeId 
							WHERE lf.FeatureId = @FeatureId
							FOR XML PATH('row'), TYPE, ROOT('lf'))
				FOR XML PATH('r')
	)

    SELECT @logSPOldData = CONVERT(NVARCHAR(MAX),@xml)
    
    BEGIN TRY
		MERGE dbo.LicenseeFeature lf
		USING (SELECT LicenseeId, LaunchDate, TerminationDate FROM @tblLicenseeoffered) AS t
			ON	(lf.LicenseeId = t.LicenseeId AND lf.FeatureId = @FeatureId)
		WHEN MATCHED AND (lf.LaunchDate <> t.LaunchDate OR ISNULL(lf.TerminationDate, '') <> ISNULL(t.TerminationDate, '')) THEN UPDATE SET lf.LaunchDate = t.LaunchDate, lf.TerminationDate = t.TerminationDate
		WHEN NOT MATCHED BY TARGET THEN INSERT (LicenseeId, FeatureId, LaunchDate, TerminationDate) VALUES (t.LicenseeId, @FeatureId, t.LaunchDate, t.TerminationDate);
		
		DELETE	dbo.LicenseeFeature WITH(ROWLOCK, UPDLOCK)
		WHERE	FeatureId = @FeatureId
				AND LicenseeId NOT IN (SELECT LicenseeId FROM @tblLicenseeoffered)
				
    END TRY
    BEGIN CATCH
        SELECT	@ErrCode = 103
                ,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](2000, @Language) + ERROR_MESSAGE() -- Fail to edit feature's clients. Please try again.
        RETURN
    END CATCH        

    -- Write log
    SET @xml = (SELECT	@FeatureId AS '@fid'
						,@FeatureName AS '@fn'
						,(SELECT	l.LicenseeId AS '@lid'
									,l.LicenseeName AS '@ln'
									,lf.LaunchDate AS '@lfld'
									,lf.TerminationDate AS '@lftd'
							FROM dbo.Licensee l WITH (NOLOCK)
								INNER JOIN dbo.LicenseeFeature lf WITH(NOLOCK) ON l.LicenseeId = lf.LicenseeId 
							WHERE
								l.LicenseeId IN (SELECT LicenseeId FROM @tblLicenseeoffered)
								AND lf.FeatureId = @FeatureId
							FOR XML PATH('row'), TYPE, ROOT('lf'))
				FOR XML PATH('r')
	)       
        
    SELECT @logSPData = CONVERT(NVARCHAR(MAX),@xml)
        ,@endRun    = GETDATE()  
        ,@duration    = DATEDIFF(MILLISECOND, @startRun, @endRun)   
        ,@procName    = OBJECT_NAME(@@PROCID)
    
    EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId         = @UserId
		,@SPName        = @procName
		,@Language      = @Language
		,@IP            = @IP
		,@Data          = @logSPData
		,@OldData       = @logSPOlddata
		,@Duration      = @Duration

	DECLARE @Licensee TABLE (LicenseeId INT, LaunchDate DATETIME, TerminationDate DATETIME)
	DECLARE @LicenseeId INT

	SELECT  @procName = SPName, @tempEndRun = GETDATE() FROM dbo.LogAction WITH(NOLOCK) WHERE LogActionId = 501 -- write log for client

	UPDATE b
	SET b.IsDelete = 1
	FROM @tblLicenseebefore b
		INNER JOIN @tblLicenseeoffered a ON b.LicenseeId = a.LicenseeId
	WHERE ISNULL(b.LaunchDate, CONVERT(DATETIME, '19700101')) = ISNULL(a.LaunchDate, CONVERT(DATETIME, '19700101'))
		AND ISNULL(b.TerminationDate, CONVERT(DATETIME, '19700101')) = ISNULL(a.TerminationDate, CONVERT(DATETIME, '19700101'))

	UPDATE a
	SET a.IsDelete = 1
	FROM @tblLicenseebefore b
		INNER JOIN @tblLicenseeoffered a ON b.LicenseeId = a.LicenseeId
	WHERE ISNULL(b.LaunchDate, CONVERT(DATETIME, '19700101')) = ISNULL(a.LaunchDate, CONVERT(DATETIME, '19700101'))
		AND ISNULL(b.TerminationDate, CONVERT(DATETIME, '19700101')) = ISNULL(a.TerminationDate, CONVERT(DATETIME, '19700101'))

	DELETE @tblLicenseebefore WHERE IsDelete = 1
	DELETE @tblLicenseeoffered WHERE IsDelete = 1

	WHILE 1=1
	BEGIN
		SELECT @tempStartRun = GETDATE(), @LicenseeId = NULL, @logSPData = NULL, @logSPOlddata = NULL
		
		IF EXISTS (SELECT TOP 1 1 FROM @tblLicenseebefore)
		BEGIN
			SELECT TOP 1 @LicenseeId = LicenseeId FROM @tblLicenseebefore ORDER BY LicenseeId

			DELETE @Licensee
			DELETE @tblLicenseebefore OUTPUT DELETED.LicenseeId, DELETED.LaunchDate, DELETED.TerminationDate INTO @Licensee WHERE LicenseeId = @LicenseeId

			SET @xml = (SELECT	l.LicenseeId		AS '@lid'
								,l.LicenseeName		AS '@ln'
								,(
								SELECT	FeatureId			AS '@fid'
											,FeatureName		AS '@fn'
											,LaunchDate			AS '@lld'
											,TerminationDate	AS '@ltd'
								FROM (
									SELECT	@FeatureId AS FeatureId, @FeatureName AS FeatureName, LaunchDate, TerminationDate
									FROM @Licensee
									UNION ALL
									SELECT	f.FeatureId, FeatureName, LaunchDate, TerminationDate
									FROM LicenseeFeature lf WITH(NOLOCK)
										INNER JOIN Feature f WITH(NOLOCK) ON lf.FeatureId = f.FeatureId AND lf.LicenseeId = @LicenseeId
									WHERE f.FeatureId <> @FeatureId
								) AS A
								ORDER BY FeatureId
								FOR XML PATH('row'), ROOT('lf'), TYPE)
						FROM dbo.Licensee l WITH(NOLOCK)
						WHERE l.LicenseeId = @LicenseeId
						FOR XML PATH('r'), TYPE
			)
			SELECT @logSPOlddata = CONVERT(NVARCHAR(MAX), @xml)

			BEGIN
				DELETE @tblLicenseeoffered WHERE LicenseeId = @LicenseeId

				SET @xml = (SELECT	l.LicenseeId		AS '@lid'
									,l.LicenseeName		AS '@ln'
									,(SELECT	f.FeatureId AS '@fid', FeatureName AS '@fn', LaunchDate AS '@lld', TerminationDate AS '@ltd'
									FROM LicenseeFeature lf WITH(NOLOCK)
										INNER JOIN Feature f WITH(NOLOCK) ON lf.FeatureId = f.FeatureId AND lf.LicenseeId = @LicenseeId
									ORDER BY lf.FeatureId
									FOR XML PATH('row'), ROOT('lf'), TYPE)
							FROM dbo.Licensee l WITH(NOLOCK)
							WHERE l.LicenseeId = @LicenseeId
							FOR XML PATH('r'), TYPE
				)
				SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
			END
		END
		ELSE IF EXISTS (SELECT TOP 1 1 FROM @tblLicenseeoffered)
		BEGIN
			SELECT TOP 1 @LicenseeId = LicenseeId FROM @tblLicenseeoffered ORDER BY LicenseeId

			DELETE @tblLicenseeoffered WHERE LicenseeId = @LicenseeId

			SET @xml = (SELECT	l.LicenseeId		AS '@lid'
								,l.LicenseeName		AS '@ln'
								,(SELECT	f.FeatureId AS '@fid', FeatureName AS '@fn', LaunchDate AS '@lld', TerminationDate AS '@ltd'
								FROM LicenseeFeature lf WITH(NOLOCK)
									INNER JOIN Feature f WITH(NOLOCK) ON lf.FeatureId = f.FeatureId AND lf.LicenseeId = @LicenseeId
								WHERE f.FeatureId <> @FeatureId
								ORDER BY f.FeatureId
								FOR XML PATH('row'), ROOT('lf'), TYPE)
						FROM dbo.Licensee l WITH(NOLOCK)
						WHERE l.LicenseeId = @LicenseeId
						FOR XML PATH('r'), TYPE
			)
			SELECT @logSPOlddata = CONVERT(NVARCHAR(MAX), @xml)
			
			SET @xml = (SELECT	l.LicenseeId		AS '@lid'
								,l.LicenseeName		AS '@ln'
								,(SELECT	f.FeatureId AS '@fid', FeatureName AS '@fn', LaunchDate AS '@lld', TerminationDate AS '@ltd'
								FROM LicenseeFeature lf WITH(NOLOCK)
									INNER JOIN Feature f WITH(NOLOCK) ON lf.FeatureId = f.FeatureId AND lf.LicenseeId = @LicenseeId
								ORDER BY f.FeatureId
								FOR XML PATH('row'), ROOT('lf'), TYPE)
						FROM dbo.Licensee l WITH(NOLOCK)
						WHERE l.LicenseeId = @LicenseeId
						FOR XML PATH('r'), TYPE
			)
			SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		END
		ELSE
			BREAK

		SELECT	@endRun		= GETDATE()  
				,@duration	= DATEDIFF(MILLISECOND, @startRun, @tempEndRun) + DATEDIFF(MILLISECOND, @tempStartRun, @endRun)

		EXEC dbo.OIC_LogRunSpIns_xtest
			@UserId			= @UserId
			,@SPName		= @procName
			,@Language		= @Language
			,@IP			= @IP
			,@Data          = @logSPData
			,@OldData       = @logSPOlddata
			,@Duration		= @Duration
	END
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeFeatureByLicenseeSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeFeatureByLicenseeSel    Script Date: 5/4/2017 12:15:56 PM ******/
/*<info serverAlias="DBOIC-bodb_OIC" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[OIC_LicenseeFeatureByLicenseeSel]
	@LicenseeId INT
AS

/*
	Created by: Percy
	Date: 2017-03-28
	Task: Select feature by client [RedmineID: #70323]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	Param's Explanation:
		
*/

BEGIN
	SET NOCOUNT ON
	
	SELECT
		f.FeatureId,
		f.FeatureName,
		lf.LaunchDate,
		lf.TerminationDate
	FROM dbo.Feature f WITH(NOLOCK)
		LEFT JOIN dbo.LicenseeFeature lf WITH(NOLOCK) ON f.FeatureId = lf.FeatureId AND lf.LicenseeId = @LicenseeId
	ORDER BY f.FeatureId
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeFeatureByLicenseeSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeFeatureByLicenseeSel_xtest    Script Date: 5/4/2017 12:15:56 PM ******/
/*<info serverAlias="DBOIC-bodb_OIC" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[OIC_LicenseeFeatureByLicenseeSel_xtest]
	@LicenseeId INT
AS

/*
	Created by: Percy
	Date: 2017-03-28
	Task: Select feature by client [RedmineID: #70323]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	Param's Explanation:
		
*/

BEGIN
	SET NOCOUNT ON
	
	SELECT
		f.FeatureId,
		f.FeatureName,
		lf.LaunchDate,
		lf.TerminationDate
	FROM dbo.Feature f WITH(NOLOCK)
		LEFT JOIN dbo.LicenseeFeature lf WITH(NOLOCK) ON f.FeatureId = lf.FeatureId AND lf.LicenseeId = @LicenseeId
	ORDER BY f.FeatureId
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeFeatureByLicenseeUpd]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeFeatureByLicenseeUpd    Script Date: 5/3/2017 10:41:16 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeFeatureByLicenseeUpd    Script Date: 4/24/2017 10:21:28 AM ******/
/*<info serverAlias="DBOIC-bodb_OIC" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[OIC_LicenseeFeatureByLicenseeUpd]
	@LicenseeId			INT,
	@SelectedFeature	XML,
	@UserId				INT,
	@Language			VARCHAR(10)		= 'E',
	@IP					VARCHAR(50)		= NULL,
	@ErrCode			INT				= 0			OUTPUT,
	@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS

/*
	Created by: Percy
	Date: 2017-03-28
	Task: Update Client feature by client [RedmineID: #70323]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	Param's Explanation:
	- @SelectedFeature: list of Feature			
		<root>
			<row FeatureId="1" launchdate="2014-12-19" terminationdate="2016-05-13"/>
			<row FeatureId="3" launchdate="2014-12-19"/>
		</root>
*/

BEGIN
	SET NOCOUNT ON

	-- For write log
	DECLARE @startRun	DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPOlddata	NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
		,@LicenseeName	NVARCHAR(50)

	SET @startRun = GETDATE()

	DECLARE @tblFeatureOffered TABLE (FeatureId INT, LaunchDate DATETIME, TerminationDate DATETIME)

	SELECT	@LicenseeName = LicenseeName
	FROM	dbo.Licensee WITH (NOLOCK)
	WHERE	LicenseeId = @LicenseeId

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](5, @Language) -- Licensee does not exist.
		RETURN
	END

	INSERT INTO @tblFeatureOffered (FeatureId, LaunchDate, TerminationDate)
	SELECT	t.c.value('@FeatureId', 'int') AS FeatureId
			,t.c.value('@launchdate', 'datetime') AS LaunchDate
			,t.c.value('@terminationdate', 'datetime') AS TerminationDate
	FROM @SelectedFeature.nodes('root/row') t(c)

	IF @@ERROR <> 0
	BEGIN
		SELECT	@ErrCode = 102
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](2001, @Language) -- Fail to edit client's features. Please try again.
		RETURN
	END

	-- get data before update/insert
	SET @xml = (
			SELECT	@LicenseeId AS '@lid'
					,@LicenseeName AS '@ln'
					,(
						SELECT	f.FeatureId AS '@fid'
								,f.FeatureName AS '@fn'
								,lf.LaunchDate AS '@lld'
								,lf.TerminationDate AS '@ltd'
						FROM dbo.LicenseeFeature lf WITH (NOLOCK)
							INNER JOIN dbo.Feature f WITH (NOLOCK) ON f.FeatureId = lf.FeatureId
						WHERE lf.LicenseeId = @LicenseeId
					FOR XML PATH('row'), ROOT('lf'), TYPE
					)
			FOR XML PATH('r'), TYPE
	)

	SELECT @logSPOldData = CONVERT(NVARCHAR(MAX), @xml)

	BEGIN TRY
		MERGE dbo.LicenseeFeature AS lf
		USING (SELECT FeatureId, LaunchDate, TerminationDate FROM @tblFeatureOffered) AS t
		ON	(lf.FeatureId = t.FeatureId AND lf.LicenseeId = @LicenseeId)
		WHEN MATCHED AND (lf.LaunchDate <> t.LaunchDate OR ISNULL(lf.TerminationDate, '') <> ISNULL(t.TerminationDate, '')) THEN UPDATE SET lf.LaunchDate = t.LaunchDate, lf.TerminationDate = t.TerminationDate
		WHEN NOT MATCHED BY TARGET THEN INSERT (LicenseeId, FeatureId, LaunchDate, TerminationDate) VALUES(@LicenseeId, t.FeatureId, t.LaunchDate, t.TerminationDate)
		WHEN NOT MATCHED BY SOURCE AND lf.LicenseeId = @LicenseeId THEN DELETE;
	END TRY

	BEGIN CATCH
		SELECT	@ErrCode = 103
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](2001, @Language) + ERROR_MESSAGE() -- Fail to edit client's features. Please try again.
		RETURN
	END CATCH

	-- Write log
	SET @xml = (
			SELECT	@LicenseeId AS '@lid'
					,@LicenseeName AS '@ln'
					,(
						SELECT	f.FeatureId AS '@fid'
								,f.FeatureName AS '@fn'
								,lf.LaunchDate AS '@lld'
								,lf.TerminationDate AS '@ltd'
						FROM dbo.LicenseeFeature lf WITH (NOLOCK)
							INNER JOIN dbo.Feature f WITH (NOLOCK) ON f.FeatureId = lf.FeatureId
						WHERE
							lf.FeatureId IN (SELECT FeatureId FROM @tblFeatureOffered)
							AND lf.LicenseeId = @LicenseeId
						FOR XML PATH('row'),ROOT('lf'),TYPE)
			FOR XML PATH('r'),TYPE
	)

	SELECT @logSPData	= CONVERT(NVARCHAR(MAX), @xml)
		,@endRun		= GETDATE()
		,@duration		= DATEDIFF(MILLISECOND, @startRun, @endRun)
		,@procName		= OBJECT_NAME(@@PROCID)

		EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOlddata
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeFeatureByLicenseeUpd_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeFeatureByLicenseeUpd_xtest    Script Date: 4/24/2017 10:21:28 AM ******/
/*<info serverAlias="DBOIC-bodb_OIC" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[OIC_LicenseeFeatureByLicenseeUpd_xtest]
	@LicenseeId			INT,
	@SelectedFeature	XML,
	@UserId				INT,
	@Language			VARCHAR(10)		= 'E',
	@IP					VARCHAR(50)		= NULL,
	@ErrCode			INT				= 0			OUTPUT,
	@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS

/*
	Created by: Percy
	Date: 2017-03-28
	Task: Update Client feature by client [RedmineID: #70323]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	Param's Explanation:
	- @SelectedFeature: list of Feature			
		<root>
			<row FeatureId="1" launchdate="2014-12-19" terminationdate="2016-05-13"/>
			<row FeatureId="3" launchdate="2014-12-19"/>
		</root>
*/

BEGIN
	SET NOCOUNT ON

	-- For write log
	DECLARE @startRun	DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPOlddata	NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
		,@LicenseeName	NVARCHAR(50)

	SET @startRun = GETDATE()

	DECLARE @tblFeatureOffered TABLE (FeatureId INT, LaunchDate DATETIME, TerminationDate DATETIME)

	SELECT	@LicenseeName = LicenseeName
	FROM	dbo.Licensee WITH (NOLOCK)
	WHERE	LicenseeId = @LicenseeId

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](5, @Language) -- Licensee does not exist.
		RETURN
	END

	INSERT INTO @tblFeatureOffered (FeatureId, LaunchDate, TerminationDate)
	SELECT	t.c.value('@FeatureId', 'int') AS FeatureId
			,t.c.value('@launchdate', 'datetime') AS LaunchDate
			,t.c.value('@terminationdate', 'datetime') AS TerminationDate
	FROM @SelectedFeature.nodes('root/row') t(c)

	IF @@ERROR <> 0
	BEGIN
		SELECT	@ErrCode = 102
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](2001, @Language) -- Fail to edit client's features. Please try again.
		RETURN
	END

	-- get data before update/insert
	SET @xml = (
			SELECT	@LicenseeId AS '@lid'
					,@LicenseeName AS '@ln'
					,(
						SELECT	f.FeatureId AS '@fid'
								,f.FeatureName AS '@fn'
								,lf.LaunchDate AS '@lld'
								,lf.TerminationDate AS '@ltd'
						FROM dbo.LicenseeFeature lf WITH (NOLOCK)
							INNER JOIN dbo.Feature f WITH (NOLOCK) ON f.FeatureId = lf.FeatureId
						WHERE lf.LicenseeId = @LicenseeId
					FOR XML PATH('row'), ROOT('lf'), TYPE
					)
			FOR XML PATH('r'), TYPE
	)

	SELECT @logSPOldData = CONVERT(NVARCHAR(MAX), @xml)

	BEGIN TRY
		MERGE dbo.LicenseeFeature AS lf
		USING (SELECT FeatureId, LaunchDate, TerminationDate FROM @tblFeatureOffered) AS t
		ON	(lf.FeatureId = t.FeatureId AND lf.LicenseeId = @LicenseeId)
		WHEN MATCHED AND (lf.LaunchDate <> t.LaunchDate OR ISNULL(lf.TerminationDate, '') <> ISNULL(t.TerminationDate, '')) THEN UPDATE SET lf.LaunchDate = t.LaunchDate, lf.TerminationDate = t.TerminationDate
		WHEN NOT MATCHED BY TARGET THEN INSERT (LicenseeId, FeatureId, LaunchDate, TerminationDate) VALUES(@LicenseeId, t.FeatureId, t.LaunchDate, t.TerminationDate)
		WHEN NOT MATCHED BY SOURCE AND lf.LicenseeId = @LicenseeId THEN DELETE;
	END TRY

	BEGIN CATCH
		SELECT	@ErrCode = 103
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](2001, @Language) + ERROR_MESSAGE() -- Fail to edit client's features. Please try again.
		RETURN
	END CATCH

	-- Write log
	SET @xml = (
			SELECT	@LicenseeId AS '@lid'
					,@LicenseeName AS '@ln'
					,(
						SELECT	f.FeatureId AS '@fid'
								,f.FeatureName AS '@fn'
								,lf.LaunchDate AS '@lld'
								,lf.TerminationDate AS '@ltd'
						FROM dbo.LicenseeFeature lf WITH (NOLOCK)
							INNER JOIN dbo.Feature f WITH (NOLOCK) ON f.FeatureId = lf.FeatureId
						WHERE
							lf.FeatureId IN (SELECT FeatureId FROM @tblFeatureOffered)
							AND lf.LicenseeId = @LicenseeId
						FOR XML PATH('row'),ROOT('lf'),TYPE)
			FOR XML PATH('r'),TYPE
	)

	SELECT @logSPData	= CONVERT(NVARCHAR(MAX), @xml)
		,@endRun		= GETDATE()
		,@duration		= DATEDIFF(MILLISECOND, @startRun, @endRun)
		,@procName		= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOlddata
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeFeatureListSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeFeatureListSel    Script Date: 9/11/2017 11:37:18 PM ******/
CREATE PROCEDURE [dbo].[OIC_LicenseeFeatureListSel] 
	@UserId				INT
	,@SelectedLicenseeType VARCHAR(50)	= 'All'
	,@LicenseeName		NVARCHAR(50)		= '%'
	,@LicenseeStatusIds	VARCHAR(50)	= 'All'
	,@SelectedFeature	VARCHAR(500)	= 'All'
	,@FeatureShown		VARCHAR(500)
	,@FeatureStatusId	TINYINT			= 0
	,@LaunchFrom		DATETIME		= NULL
	,@LaunchTo			DATETIME		= NULL
	,@TerminationFrom	DATETIME		= NULL
	,@TerminationTo		DATETIME		= NULL
		
	,@PageSize			INT = 10
	,@PageIndex			INT	= 0 
	,@TotalRecords		INT = 0 OUTPUT
AS

/*
	Created by: Percy
	Date: 2017-03-28
	Task: Licensee Feature list [RedmineID: #70323]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	- 20170828@Scofield: Update LicenseeStatusIds [#82144]
	
	Param's Explanation:
		@SelectedFeature: multiple selection feature
		@FeatureShown: list features shall be shown, support multiple selection
		@PageIndex: 0 - the first page
		@FeatureStatusId:
			0: All
			1: Upcoming
			2: Launched
			3: To be terminated
			4: Terminated
		
*/

BEGIN
	SET NOCOUNT ON
	DECLARE @DynamicPIVOT		VARCHAR(MAX)
			,@strFeatureName	VARCHAR(MAX)
	
	DECLARE @RowCount	INT	
			,@RowStart	INT
			,@RowEnd	INT
	
	SELECT @PageIndex = @PageIndex,
			@RowStart = @PageSize * @PageIndex + 1
			,@RowEnd = @RowStart + @PageSize - 1
	
	DECLARE @today				DATETIME = CONVERT(DATE, GETDATE())
	DECLARE @tblFeature			TABLE (FeatureId INT)
	DECLARE @tblLicenseeType	TABLE (LicenseeTypeId TINYINT)
	CREATE TABLE #tblLicenseeFeature (LicenseeId INT, FeatureId INT, IsFilled BIT)
	
	CREATE TABLE #tblResult	(
		RowNumber			INT
		,LicenseeId			INT
		,LicenseeName		NVARCHAR(50)
		,StatusName			VARCHAR(30)
		,TypeName			VARCHAR(30)
	)
							
	INSERT INTO @tblFeature(FeatureId)
	SELECT	p.FeatureId
	FROM	dbo.Feature p WITH(NOLOCK)
	WHERE   @SelectedFeature = 'All' 
			OR p.FeatureId IN (SELECT val FROM dbo.strSplit(@SelectedFeature,','))
						
	INSERT INTO #tblLicenseeFeature(LicenseeId, FeatureId, IsFilled)
	SELECT	lp.LicenseeId, p.FeatureId, 0
	FROM	@tblFeature p				
		RIGHT JOIN dbo.LicenseeFeature lp WITH(NOLOCK) 
			ON	p.FeatureId = lp.FeatureId

	UPDATE t
	SET IsFilled = 1
	FROM #tblLicenseeFeature t	
		INNER JOIN dbo.LicenseeFeature lp WITH(NOLOCK) 
			ON	t.LicenseeId = lp.LicenseeId AND t.FeatureId = lp.FeatureId
	WHERE
		(@LaunchFrom IS NULL
			OR (@LaunchFrom IS NOT NULL AND lp.LaunchDate >= @LaunchFrom))
		AND (@LaunchTo IS NULL
			OR (@LaunchTo IS NOT NULL AND lp.LaunchDate <= @LaunchTo))
		AND (@TerminationFrom IS NULL
			OR (@TerminationFrom IS NOT NULL AND lp.TerminationDate >= @TerminationFrom))
		AND (@TerminationTo IS NULL
			OR (@TerminationTo IS NOT NULL AND lp.TerminationDate <= @TerminationTo))
		AND (@FeatureStatusId = 0
			OR (@FeatureStatusId = 1 AND lp.LaunchDate > @today)
			OR (@FeatureStatusId = 2 AND lp.LaunchDate <= @today)
			OR (@FeatureStatusId = 3 AND lp.LaunchDate <= @today AND lp.TerminationDate IS NOT NULL)
			OR (@FeatureStatusId = 4 AND lp.TerminationDate < @today))

	IF @SelectedLicenseeType = 'All'
	BEGIN
		INSERT INTO @tblLicenseeType (LicenseeTypeId)
		SELECT	LicenseeTypeId
		FROM	dbo.UserLicenseeType WITH(NOLOCK)
		WHERE	UserId = @UserId
	END
	ELSE
	BEGIN
		INSERT INTO @tblLicenseeType (LicenseeTypeId)
		SELECT CONVERT(TINYINT, val) FROM dbo.strSplit(@SelectedLicenseeType, ',')

		DELETE lt
		FROM @tblLicenseeType lt
			LEFT JOIN dbo.UserLicenseeType ult WITH(NOLOCK) ON lt.LicenseeTypeId = ult.LicenseeTypeId AND ult.UserId = @UserId
		WHERE ult.LicenseeTypeId IS NULL
	END
					
	INSERT INTO #tblResult( 
			RowNumber
			,LicenseeId
			,LicenseeName
			,StatusName
			,TypeName
	)	
	SELECT	ROW_NUMBER() OVER(ORDER BY LicenseeName) AS RowNumber
			, l.LicenseeId
			,l.LicenseeName
			,ls.LicenseeStatusName
			,lt.LicenseeTypeName
	FROM	dbo.Licensee l
		INNER JOIN LicenseeType lt 
			ON	l.licenseeTypeId = lt.LicenseeTypeId
		INNER JOIN LicenseeStatus ls 
			ON	l.LicenseeStatusId = ls.LicenseeStatusId	
	WHERE	l.LicenseeTypeId IN (SELECT LicenseeTypeId FROM @tblLicenseeType)
			AND l.LicenseeName LIKE ISNULL(@LicenseeName,'%') + '%'
			AND (@LicenseeStatusIds = 'All' OR l.LicenseeStatusId IN (SELECT val FROM dbo.strSplit(@LicenseeStatusIds,','))) 	
	GROUP BY l.LicenseeId
			,l.LicenseeName
			,ls.LicenseeStatusName
			,lt.LicenseeTypeName						
	
	IF @TotalRecords = 0
	BEGIN
		SELECT @TotalRecords = COUNT(1)
		FROM #tblResult
	END
			
	SELECT	@strFeatureName = ISNULL(@strFeatureName, '') + '[' +  Featurename + '],'
	FROM	dbo.Feature WITH(NOLOCK)
	WHERE	FeatureId IN (SELECT val FROM dbo.strSplit(@FeatureShown,','))
	ORDER BY FeatureId
	
	SELECT @strFeatureName = LEFT(@strFeatureName,LEN(@strFeatureName) -1)	
	
	SELECT @DynamicPIVOT = 'SELECT LicenseeId
								,LicenseeName
								,StatusName
								,TypeName
								,' + @strFeatureName +
	'FROM (
			SELECT	 RowNumber, t.LicenseeId, t.LicenseeName, t.StatusName, t.TypeName, p.Featurename
			,CONVERT(VARCHAR(1), ISNULL(IsFilled, 0)) + '','' + CONVERT(VARCHAR(10), lp.LaunchDate, 20) + CASE WHEN ISNULL(lp.TerminationDate, '''') <> ''''THEN + '','' + CONVERT(VARCHAR(10), lp.TerminationDate, 20) ELSE '''' END AS [Date]
			FROM	 #tblResult t WITH(NOLOCK)
				LEFT JOIN dbo.LicenseeFeature lp WITH(NOLOCK)
					ON	t.LicenseeId = lp.LicenseeId				
				LEFT JOIN dbo.Feature p WITH(NOLOCK)
					ON	lp.FeatureId = p.FeatureId
				LEFT JOIN #tblLicenseeFeature tlp
					ON t.LicenseeId = tlp.LicenseeId AND lp.FeatureId = tlp.FeatureId
		 )p
	PIVOT (
		MAX(p.[Date]) FOR Featurename IN (' + @strFeatureName + ')
	) Result
	WHERE RowNumber BETWEEN ' + CONVERT(VARCHAR(10),@RowStart) + ' AND ' + CONVERT(VARCHAR(10),@RowEnd) + ''
	
	EXEC (@DynamicPIVOT)
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeFeatureListSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OIC_LicenseeFeatureListSel_xtest] 
	@UserId				INT
	,@SelectedLicenseeType VARCHAR(50)	= 'All'
	,@LicenseeName		NVARCHAR(50)		= '%'
	,@LicenseeStatusIds	VARCHAR(50)	= 'All'
	,@SelectedFeature	VARCHAR(500)	= 'All'
	,@FeatureShown		VARCHAR(500)
	,@FeatureStatusId	TINYINT			= 0
	,@LaunchFrom		DATETIME		= NULL
	,@LaunchTo			DATETIME		= NULL
	,@TerminationFrom	DATETIME		= NULL
	,@TerminationTo		DATETIME		= NULL
		
	,@PageSize			INT = 10
	,@PageIndex			INT	= 0 
	,@TotalRecords		INT = 0 OUTPUT
AS

/*
	Created by: Percy
	Date: 2017-03-28
	Task: Licensee Feature list [RedmineID: #70323]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	- 20170828@Scofield: Update LicenseeStatusIds [#82144]
	
	Param's Explanation:
		@SelectedFeature: multiple selection feature
		@FeatureShown: list features shall be shown, support multiple selection
		@PageIndex: 0 - the first page
		@FeatureStatusId:
			0: All
			1: Upcoming
			2: Launched
			3: To be terminated
			4: Terminated
		
*/

BEGIN
	SET NOCOUNT ON
	DECLARE @DynamicPIVOT		VARCHAR(MAX)
			,@strFeatureName	VARCHAR(MAX)
	
	DECLARE @RowCount	INT	
			,@RowStart	INT
			,@RowEnd	INT
	
	SELECT @PageIndex = @PageIndex,
			@RowStart = @PageSize * @PageIndex + 1
			,@RowEnd = @RowStart + @PageSize - 1
	
	DECLARE @today				DATETIME = CONVERT(DATE, GETDATE())
	DECLARE @tblFeature			TABLE (FeatureId INT)
	DECLARE @tblLicenseeType	TABLE (LicenseeTypeId TINYINT)
	CREATE TABLE #tblLicenseeFeature (LicenseeId INT, FeatureId INT, IsFilled BIT)
	
	CREATE TABLE #tblResult	(
		RowNumber			INT
		,LicenseeId			INT
		,LicenseeName		NVARCHAR(50)
		,StatusName			VARCHAR(30)
		,TypeName			VARCHAR(30)
	)
							
	INSERT INTO @tblFeature(FeatureId)
	SELECT	p.FeatureId
	FROM	dbo.Feature p WITH(NOLOCK)
	WHERE   @SelectedFeature = 'All' 
			OR p.FeatureId IN (SELECT val FROM dbo.strSplit(@SelectedFeature,','))
						
	INSERT INTO #tblLicenseeFeature(LicenseeId, FeatureId, IsFilled)
	SELECT	lp.LicenseeId, p.FeatureId, 0
	FROM	@tblFeature p				
		RIGHT JOIN dbo.LicenseeFeature lp WITH(NOLOCK) 
			ON	p.FeatureId = lp.FeatureId

	UPDATE t
	SET IsFilled = 1
	FROM #tblLicenseeFeature t	
		INNER JOIN dbo.LicenseeFeature lp WITH(NOLOCK) 
			ON	t.LicenseeId = lp.LicenseeId AND t.FeatureId = lp.FeatureId
	WHERE
		(@LaunchFrom IS NULL
			OR (@LaunchFrom IS NOT NULL AND lp.LaunchDate >= @LaunchFrom))
		AND (@LaunchTo IS NULL
			OR (@LaunchTo IS NOT NULL AND lp.LaunchDate <= @LaunchTo))
		AND (@TerminationFrom IS NULL
			OR (@TerminationFrom IS NOT NULL AND lp.TerminationDate >= @TerminationFrom))
		AND (@TerminationTo IS NULL
			OR (@TerminationTo IS NOT NULL AND lp.TerminationDate <= @TerminationTo))
		AND (@FeatureStatusId = 0
			OR (@FeatureStatusId = 1 AND lp.LaunchDate > @today)
			OR (@FeatureStatusId = 2 AND lp.LaunchDate <= @today)
			OR (@FeatureStatusId = 3 AND lp.LaunchDate <= @today AND lp.TerminationDate IS NOT NULL)
			OR (@FeatureStatusId = 4 AND lp.TerminationDate < @today))

	IF @SelectedLicenseeType = 'All'
	BEGIN
		INSERT INTO @tblLicenseeType (LicenseeTypeId)
		SELECT	LicenseeTypeId
		FROM	dbo.UserLicenseeType WITH(NOLOCK)
		WHERE	UserId = @UserId
	END
	ELSE
	BEGIN
		INSERT INTO @tblLicenseeType (LicenseeTypeId)
		SELECT CONVERT(TINYINT, val) FROM dbo.strSplit(@SelectedLicenseeType, ',')

		DELETE lt
		FROM @tblLicenseeType lt
			LEFT JOIN dbo.UserLicenseeType ult WITH(NOLOCK) ON lt.LicenseeTypeId = ult.LicenseeTypeId AND ult.UserId = @UserId
		WHERE ult.LicenseeTypeId IS NULL
	END
					
	INSERT INTO #tblResult( 
			RowNumber
			,LicenseeId
			,LicenseeName
			,StatusName
			,TypeName
	)	
	SELECT	ROW_NUMBER() OVER(ORDER BY LicenseeName) AS RowNumber
			, l.LicenseeId
			,l.LicenseeName
			,ls.LicenseeStatusName
			,lt.LicenseeTypeName
	FROM	dbo.Licensee l
		INNER JOIN LicenseeType lt 
			ON	l.licenseeTypeId = lt.LicenseeTypeId
		INNER JOIN LicenseeStatus ls 
			ON	l.LicenseeStatusId = ls.LicenseeStatusId	
	WHERE	l.LicenseeTypeId IN (SELECT LicenseeTypeId FROM @tblLicenseeType)
			AND l.LicenseeName LIKE ISNULL(@LicenseeName,'%') + '%'
			AND (@LicenseeStatusIds = 'All' OR l.LicenseeStatusId IN (SELECT val FROM dbo.strSplit(@LicenseeStatusIds,','))) 	
	GROUP BY l.LicenseeId
			,l.LicenseeName
			,ls.LicenseeStatusName
			,lt.LicenseeTypeName						
	
	IF @TotalRecords = 0
	BEGIN
		SELECT @TotalRecords = COUNT(1)
		FROM #tblResult
	END
			
	SELECT	@strFeatureName = ISNULL(@strFeatureName, '') + '[' +  Featurename + '],'
	FROM	dbo.Feature WITH(NOLOCK)
	WHERE	FeatureId IN (SELECT val FROM dbo.strSplit(@FeatureShown,','))
	ORDER BY FeatureId
	
	SELECT @strFeatureName = LEFT(@strFeatureName,LEN(@strFeatureName) -1)	
	
	SELECT @DynamicPIVOT = 'SELECT LicenseeId
								,LicenseeName
								,StatusName
								,TypeName
								,' + @strFeatureName +
	'FROM (
			SELECT	 RowNumber, t.LicenseeId, t.LicenseeName, t.StatusName, t.TypeName, p.Featurename
			,CONVERT(VARCHAR(1), ISNULL(IsFilled, 0)) + '','' + CONVERT(VARCHAR(10), lp.LaunchDate, 20) + CASE WHEN ISNULL(lp.TerminationDate, '''') <> ''''THEN + '','' + CONVERT(VARCHAR(10), lp.TerminationDate, 20) ELSE '''' END AS [Date]
			FROM	 #tblResult t WITH(NOLOCK)
				LEFT JOIN dbo.LicenseeFeature lp WITH(NOLOCK)
					ON	t.LicenseeId = lp.LicenseeId				
				LEFT JOIN dbo.Feature p WITH(NOLOCK)
					ON	lp.FeatureId = p.FeatureId
				LEFT JOIN #tblLicenseeFeature tlp
					ON t.LicenseeId = tlp.LicenseeId AND lp.FeatureId = tlp.FeatureId
		 )p
	PIVOT (
		MAX(p.[Date]) FOR Featurename IN (' + @strFeatureName + ')
	) Result
	WHERE RowNumber BETWEEN ' + CONVERT(VARCHAR(10),@RowStart) + ' AND ' + CONVERT(VARCHAR(10),@RowEnd) + ''
	
	EXEC (@DynamicPIVOT)
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeInfoIns]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeInfoIns    Script Date: 9/11/2017 11:37:07 PM ******/
CREATE PROCEDURE [dbo].[OIC_LicenseeInfoIns]
	@UserId					INT
	,@LicenseeTypeId		TINYINT
	,@SiteName				NVARCHAR(50)
	,@CompanyName			NVARCHAR(50)	= NULL
	,@LicenseeStatusId		TINYINT
	,@IsReseller			BIT				= 0
	,@IsChineseMarketOnly	BIT				= 0
	,@SoftLaunch			DATETIME		= NULL
	,@FullLaunch			DATETIME		= NULL
	,@MainUrl				VARCHAR(3000)	= NULL
	,@APIUrl				VARCHAR(3000)	= NULL
	,@LicBackUpLink			XML				= NULL
	,@HasMainContact		BIT				= 0 -- has main contact info
	,@MainContactName		NVARCHAR(50)	= NULL
	,@Position				NVARCHAR(50)	= NULL
	,@Department			NVARCHAR(50)	= NULL
	,@Email					VARCHAR(50)		= NULL
	,@PhoneNumber			VARCHAR(50)		= NULL
	,@Skype					VARCHAR(50)		= NULL
	,@MainContactRemark		NVARCHAR(300)	= NULL
	,@LocationId			INT				= NULL
	,@CurrenciesOffered		VARCHAR(100)	= NULL
	,@LicTargetMarket		VARCHAR(1000)	= NULL
	,@LicLanguage			XML				= NULL
	,@LicLanguageSB			XML				= NULL
	,@LicService			XML				= NULL
	,@LicRestrictCountry	VARCHAR(1000)	= NULL
	,@RestrictCountryRemark	NVARCHAR(2000)	= NULL		
	,@Remark				NVARCHAR(300)	= NULL
	,@LicProduct			XML				= NULL
	,@LicFeature			XML				= NULL
	,@AMUserId				INT				
	,@PMUserId				INT				
	,@LicAccount			XML				= NULL
	,@InternalURL			VARCHAR(3000)	= NULL
	
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2014-12-18
	Task: Insert Licensee [Redmine:#27752]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160511@Percy: Change type of input param @LicFeature [RedmineID: #56935]
		- 20160805@Percy: Expand length of params: @LicTargetMarket, @LicRestrictCountry [RedmineID: #62099]
		- 20160823@Percy: Add param: @LicLanguageSB - Sportbook offered language [RedmineID: #62883]
		- 20170517@Percy: Add Chinese Market Only and Internal Backend URL [RedmineID: #74330]
		- 20170802@Percy: Add Url testing account - add element into @LicAccount [RedmineID: #80712]
		- 20170809@Percy: Extend Url length [RedmineID: #81392]
		- 20170828@Scofield: Add Reseller [#82144]
	
	Param's Explanation:
	* @LicBackupLink
		<root>
			<row val="link1" />
			<row val="link2" />
		</root>
	* @LicService: List of Services
		Format:
				<root>
					<row pid="1" val="kathy.nguyen" />
					<row pid="2" val="password" />
					<row pid="3" val="http:..." />
					<row pid="4" val="http:..." />
				</root>
	* @LicLanguage, @LicLanguageSB
		Format:
				<root>
					<row id="1" />
					<row id="2" />
				</root>
	* @LicProduct, @LicFeature: list of product, feature
				<root>
					<row id="1" launchdate="2014-12-19" terminationdate="2016-05-11"/>
					<row id="3" launchdate="2014-12-19"/>
				</root>
				
	* @LicAccount:
				<root>
					<row order="1" type="1" username="webaccount" password="abc" url="https://" />
					<row order="1" type="2" username="csd" password="1234" url="https://" />
					<row order="1" type="3" username="training" password="12abc" url="https://" />
				</root>
				
	* @CurrenciesOffered, @LicTargetMarket, @LicRestrictCountry
	* @ErrCode:
		= 0: 
		> 0: Specific Error.
  
	* @ErrMsg: Error description.
	
	* Log:
 */
BEGIN
	SET NOCOUNT ON
	
	DECLARE @LicenseeId INT

	-- For write log
	DECLARE 
		@startRun					DATETIME
		,@endRun					DATETIME
		,@duration					INT
		,@logSPData					NVARCHAR(MAX)
		,@xml						XML
		,@procName					VARCHAR(200)
		-- log step 1
		,@log_backupLink			XML
		,@log_maincontact			XML
		,@log_currency				XML
		,@log_targetedMarket		XML
		,@log_restrictedLocation	XML
		,@log_language				XML
		,@log_languageSB			XML
		,@log_service				XML
		-- log step 2
		,@log_product				XML
		,@log_feature				XML
		-- log step 3
		,@log_account				XML

	SET @startRun = GETDATE()
	
	-- check licensee name
	EXEC dbo.OIC_LicenseeNameChecking
		@SiteName	= @SiteName
		,@Language	= @Language
		,@ErrCode	= @ErrCode	OUTPUT
		,@ErrMsg	= @ErrMsg	OUTPUT
	
	IF @ErrCode <> 0
	BEGIN
		SELECT @ErrCode, @ErrMsg
		RETURN
	END
		
	-- Step1: Insert general info
		EXEC dbo.OIC_LicenseeInfoIns_Step1
		@UserId						= @UserId
		,@LicenseeTypeId			= @LicenseeTypeId
		,@SiteName					= @SiteName
		,@CompanyName				= @CompanyName
		,@LicenseeStatusId			= @LicenseeStatusId
		,@IsReseller				= @IsReseller
		,@IsChineseMarketOnly		= @IsChineseMarketOnly
		,@SoftLaunch				= @SoftLaunch
		,@FullLaunch				= @FullLaunch
		,@MainUrl					= @MainUrl
		,@APIUrl					= @APIUrl
		,@LicBackUpLink				= @LicBackUpLink
		,@HasMainContact			= @HasMainContact -- has main contact info
		,@MainContactName			= @MainContactName
		,@Position					= @Position
		,@Department				= @Department
		,@Email						= @Email
		,@PhoneNumber				= @PhoneNumber
		,@Skype						= @Skype
		,@MainContactRemark			= @MainContactRemark
		,@LocationId				= @LocationId
		,@CurrenciesOffered			= @CurrenciesOffered
		,@LicTargetMarket			= @LicTargetMarket
		,@LicLanguage				= @LicLanguage
		,@LicLanguageSB				= @LicLanguageSB
		,@LicService				= @LicService
		,@LicRestrictCountry		= @LicRestrictCountry
		,@RestrictCountryRemark		= @RestrictCountryRemark		
		,@Remark					= @Remark
		
		,@Language					= @Language
		,@IP						= @IP
		,@ErrCode					= @ErrCode		OUTPUT
		,@ErrMsg					= @ErrMsg		OUTPUT
		
		,@LicenseeId				= @LicenseeId	OUTPUT
	
	
	IF @ErrCode <> 0
	BEGIN
		SELECT	@ErrCode = @ErrCode
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1, @Language) -- Fail to insert data step1
		
		-- Rollback Step1:
		DELETE FROM dbo.Licensee WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.UrlBackup WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.LicenseeCurrency WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.LicenseeLocationLimit WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.LicenseeLanguage  WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.LicenseeProperty  WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.Contact WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeID = @LicenseeId
		-- END rollback Step1
		
		RETURN
	END
	
	-- END step1
	
	-- Step2: Registered product & feature 
	IF @LicProduct IS NOT NULL OR @LicFeature IS NOT NULL
	BEGIN
		EXEC dbo.OIC_LicenseeInfoIns_Step2
		@UserId			= @UserId		
		,@LicenseeId	= @LicenseeId
		,@LicProduct	= @LicProduct
		,@LicFeature	= @LicFeature

		,@Language		= @Language
		,@IP			= @IP
		,@ErrCode		= @ErrCode	OUTPUT
		,@ErrMsg		= @ErrMsg	OUTPUT
		
		IF @ErrCode <> 0
		BEGIN
			SELECT	@ErrCode = @ErrCode
					,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](2, @Language) -- Fail to insert data step2
				
			-- Rollback Step1:
			DELETE FROM dbo.Licensee WITH(ROWLOCK, UPDLOCK)
			WHERE LicenseeId = @LicenseeId
			
			DELETE FROM dbo.UrlBackup WITH(ROWLOCK, UPDLOCK)
			WHERE LicenseeId = @LicenseeId
			
			DELETE FROM dbo.LicenseeCurrency WITH(ROWLOCK, UPDLOCK)
			WHERE LicenseeId = @LicenseeId
			
			DELETE FROM dbo.LicenseeLocationLimit WITH(ROWLOCK, UPDLOCK)
			WHERE LicenseeId = @LicenseeId
			
			DELETE FROM dbo.LicenseeLanguage  WITH(ROWLOCK, UPDLOCK)
			WHERE LicenseeId = @LicenseeId
			
			DELETE FROM dbo.Licensee  WITH(ROWLOCK, UPDLOCK)
			WHERE LicenseeId = @LicenseeId
			-- END rollback Step1
			
			-- Rollback Step2:
			DELETE 
			FROM dbo.LicenseeProduct WITH(ROWLOCK,UPDLOCK)
			WHERE LicenseeId = @LicenseeId
			
			DELETE
			FROM dbo.LicenseeFeature WITH(ROWLOCK, UPDLOCK)
			WHERE LicenseeId = @LicenseeId
			-- END rollback Step2	
			
			RETURN
			
		END
	END	
	-- END Step2
	
	-- Step3: Internal Person in Charge 
	EXEC dbo.OIC_LicenseeInfoIns_Step3
		@UserId				= @UserId
		,@LicenseeId		= @LicenseeId
		,@AMUserId			= @AMUserId
		,@PMUserId			= @PMUserId
		,@LicAccount		= @LicAccount
		,@Language			= @Language
		,@IP				= @IP
		,@InternalURL		= @InternalURL

		,@ErrCode			= @ErrCode	OUTPUT
		,@ErrMsg			= @ErrMsg	OUTPUT
		
	IF @ErrCode <> 0
	BEGIN
		SELECT	@ErrCode = @ErrCode
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](3, @Language) -- Fail to insert data step3
			
		-- Rollback Step1:
		DELETE FROM dbo.Licensee WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.UrlBackup WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.LicenseeCurrency WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.LicenseeLocationLimit WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.LicenseeLanguage  WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.LicenseeProperty  WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		-- END rollback Step1
		
		-- Rollback Step2:
		DELETE 
		FROM dbo.LicenseeProduct WITH(ROWLOCK,UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE
		FROM dbo.LicenseeFeature WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		-- END rollback Step2
		
		-- Rollback data Step3:
		DELETE FROM dbo.LicenseeAccountInfo WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.UserLicensee  WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		-- END rollback Step3
		
		RETURN
	END
	--END Step3

	-- write log
	SET @log_backupLink = (
							SELECT	lu.UrlValue AS '@lbul'
							FROM dbo.UrlBackup AS lu WITH (NOLOCK)
							WHERE	lu.LicenseeId = @LicenseeId
							FOR XML PATH('row'), ROOT('bk')		
						)
						
	SET @log_maincontact = (SELECT	c.ContactID			AS '@cid'
									,c.ContactName		AS '@cn'
									,c.ContactPosition	AS '@cp'
									,c.ContactDepartment AS '@cd'
									,c.ContactEmail		AS '@ce'
									,c.ContactSkype		AS '@cs'
									,c.ContactPhoneNumber	AS '@cpn'
									,c.IsMain			AS '@cim'
									,c.Remark			AS '@crm'
							FROM	dbo.Contact c
							WHERE	licenseeid = @LicenseeId AND c.IsMain = 1
							FOR XML PATH('row'), ROOT('lc')	
						)
	
	SET @log_currency = (
							SELECT	e.exchangeid AS '@cid'
									,e.Code AS '@cur'
							FROM dbo.LicenseeCurrency AS lc WITH (NOLOCK)
								INNER JOIN bodb02.dbo.Exchange AS e WITH(NOLOCK) 
									ON e.exchangeid = lc.CurrencyId
							WHERE	lc.LicenseeId = @LicenseeId
							FOR XML PATH('row'), ROOT('cr')	
						)
						
	SET @log_targetedMarket = (
							SELECT  lo.LocationId AS '@tmid'
									,lo.LocationName AS '@tmn'
							FROM dbo.LicenseeLocationLimit AS ll WITH (NOLOCK)
								INNER JOIN dbo.Location AS lo WITH(NOLOCK) 
									ON lo.LocationId = ll.LocationLimitId 
									AND ll.LicenseeLocationType = 1
							WHERE	ll.LicenseeId = @LicenseeId
							FOR XML PATH('row'), ROOT('tm')	
						)
	SET @log_restrictedLocation = (
							SELECT lo.LocationId AS '@rlid'
									,lo.LocationName AS '@rln'
							FROM dbo.LicenseeLocationLimit AS ll WITH (NOLOCK)
								INNER JOIN dbo.Location AS lo WITH(NOLOCK) 
									ON lo.LocationId = ll.LocationLimitId 
									AND ll.LicenseeLocationType = 2
							WHERE	ll.LicenseeId = @LicenseeId
							FOR XML PATH('row'), ROOT('rl')		
						)
						
	SET @log_Language = (
							SELECT	la.LanguageId AS '@llid'
									,la.LanguageName AS '@lln'
							FROM dbo.LicenseeLanguage AS ll WITH (NOLOCK)
								INNER JOIN dbo.Language AS la WITH(NOLOCK) 
									ON la.LanguageId = ll.LanguageId
							WHERE	ll.LicenseeId = @LicenseeId
							FOR XML PATH('row'), ROOT('ll')	
						)
						
	SET @log_languageSB = (
							SELECT	la.LanguageId AS '@llidsb'
									,la.LanguageName AS '@llnsb'
							FROM dbo.LicenseeProductLanguage AS ll WITH (NOLOCK)
								INNER JOIN dbo.Language AS la WITH(NOLOCK) 
									ON la.LanguageId = ll.LanguageId
							WHERE	ll.LicenseeId = @LicenseeId
							FOR XML PATH('row'), ROOT('llsb')	
						)

	SET @log_service = (	SELECT	s.ServiceId				AS '@lsid'
									,s.ServiceName				AS '@lsn'
									,p.PropertyId				as '@lspid'
									,lp.PropertyValue as '@lspv'
							FROM dbo.LicenseeProperty lp
								INNER JOIN dbo.Property p 
									ON	p.PropertyId = lp.PropertyId
								INNER JOIN dbo.Service s 
									ON	s.ServiceId = p.ServiceId
							WHERE	licenseeid = @LicenseeId
							FOR XML PATH('row'), ROOT('ls')	
						)
	SET @log_product = (	SELECT	p.ProductId AS '@lpid'
									,p.ProductName AS '@lpn'
									,p.[Order] AS '@lpod'
									,lp.LaunchDate AS '@lpl'
									,lp.TerminationDate AS '@lpt'
							FROM dbo.LicenseeProduct AS lp WITH (NOLOCK)
								INNER JOIN dbo.Product AS p WITH(NOLOCK) 
									ON	p.ProductId = lp.ProductId
							WHERE	lp.LicenseeId = @LicenseeId
							FOR XML PATH('row'), ROOT('lp')	
						)
	SET @log_feature = (	SELECT	f.FeatureId AS '@lfid'
									,f.FeatureName AS '@lfn'
									,lf.LaunchDate AS '@lfl'
									,lf.TerminationDate AS '@lft'
							FROM dbo.LicenseeFeature AS lf WITH (NOLOCK)
								INNER JOIN dbo.Feature AS f WITH(NOLOCK) 
									ON	f.FeatureId = lf.FeatureId
							WHERE	lf.LicenseeId = @LicenseeId
							FOR XML PATH('row'), ROOT('lf')	
						)
	SET @log_account = (	SELECT	la.AccountId AS '@laid'
									,la.UserName AS '@lan'
									,la.UserPwd AS '@lap'
									,la.AccountType AS '@lat'
									,la.[Order] AS '@lod'
									,la.Url AS '@lu'
							FROM dbo.LicenseeAccountInfo la WITH (NOLOCK)
							WHERE la.LicenseeId = @LicenseeId
							FOR XML PATH('row'), ROOT('la')	
						)
	
	DECLARE @pmn NVARCHAR(100), @amn NVARCHAR(100), @location NVARCHAR(50)
	
	SELECT  @pmn = pui.DisplayName
	FROM dbo.UserLicensee pul WITH(NOLOCK)
		INNER JOIN dbo.UserInfo pui WITH(NOLOCK) ON pul.UserId = pui.UserId AND pui.PositionId = 5 AND pul.LicenseeId = @LicenseeId
	
	SELECT  @amn = pui.DisplayName
	FROM dbo.UserLicensee pul WITH(NOLOCK)
		INNER JOIN dbo.UserInfo pui WITH(NOLOCK) ON pul.UserId = pui.UserId AND pui.PositionId = 6 AND pul.LicenseeId = @LicenseeId
	
	SELECT @location = LocationName FROM dbo.Location WITH(NOLOCK) WHERE LocationId = @LocationId

	-- Write log
	SET @xml = (
		SELECT	@LicenseeId					AS '@lid'
				,t.LicenseeTypeName			AS '@tn'
				,l.LicenseeName				AS '@ln'
				,l.LicenseeCompanyName		AS '@cn'
				,s.LicenseeStatusName		AS '@sn'
				,l.SoftLaunch				AS '@sl'
				,l.FullLaunch				AS '@fl'
				,l.MainUrl					AS '@mu'
				,l.APILinkageUrl			AS '@au'
				,l.RestrictedLocationRemark	AS '@rlr'			
				,l.Remark					AS '@rm'
				,l.IsChineseMarketOnly		AS '@icm'
				,l.IsReseller				AS '@res'
				,l.InternalURL				AS '@iu'
				,@location					AS '@lc'
				,@pmn						AS '@pmn'
				,@amn						AS '@amn'
				,@log_backupLink
				,@log_maincontact
				,@log_currency
				,@log_Language
				,@log_LanguageSB
				,@log_restrictedLocation
				,@log_targetedMarket
				,@log_service
				,@log_product
				,@log_feature
				,@log_account
		FROM dbo.Licensee AS l WITH (NOLOCK)
			INNER JOIN dbo.LicenseeStatus AS s WITH(NOLOCK) ON l.LicenseeStatusId = s.LicenseeStatusId
			INNER JOIN dbo.LicenseeType AS t WITH(NOLOCK) ON l.LicenseeTypeId = t.LicenseeTypeId
		WHERE l.LicenseeId = @LicenseeId
		FOR XML PATH('r'), TYPE)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeInfoIns_Step1]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeInfoIns_Step1    Script Date: 9/11/2017 11:37:09 PM ******/
CREATE PROCEDURE [dbo].[OIC_LicenseeInfoIns_Step1]
	@UserId					INT
	,@LicenseeTypeId		TINYINT
	,@SiteName				NVARCHAR(50)
	,@CompanyName			NVARCHAR(50)	= NULL
	,@LicenseeStatusId		TINYINT
	,@IsReseller			BIT				= 0
	,@IsChineseMarketOnly	BIT				= 0
	,@SoftLaunch			DATETIME		= NULL
	,@FullLaunch			DATETIME		= NULL
	,@MainUrl				VARCHAR(3000)	= NULL
	,@APIUrl				VARCHAR(3000)	= NULL
	,@LicBackUpLink			XML				= NULL
	,@HasMainContact		BIT				= 0 -- has main contact info
	,@MainContactName		NVARCHAR(50)	= NULL
	,@Position				NVARCHAR(50)	= NULL
	,@Department			NVARCHAR(50)	= NULL
	,@Email					VARCHAR(50)		= NULL
	,@PhoneNumber			VARCHAR(50)		= NULL
	,@Skype					VARCHAR(50)		= NULL
	,@MainContactRemark		NVARCHAR(300)	= NULL
	,@LocationId			INT				= NULL
	,@CurrenciesOffered		VARCHAR(100)	= NULL
	,@LicTargetMarket		VARCHAR(1000)	= NULL
	,@LicLanguage			XML				= NULL
	,@LicLanguageSB			XML				= NULL
	,@LicService			XML				= NULL
	,@LicRestrictCountry	VARCHAR(1000)	= NULL
	,@RestrictCountryRemark	NVARCHAR(2000)	= NULL		
	,@Remark				NVARCHAR(300)	= NULL
	
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
	
	,@LicenseeId			INT				= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2014-12-18
	Task: Insert client general info - Step1 [Redmine:#27752]
	DB: DBOIC/BODB_OIC 
	
	Revisions:
		- 20160805@Percy: Expand length of params: @LicTargetMarket, @LicRestrictCountry [RedmineID: #62099]
		- 20160823@Percy: Add param: @LicLanguageSB - Sportbook offered language [RedmineID: #62883]
		- 20170517@Percy: Add Chinese Market Only [RedmineID: #74330]
		- 20170809@Percy: Extend Url length [RedmineID: #81392]
		- 20170828@Scofield: Add Reseller [#82144]
	
	Param's Explanation:
	* @LicBackupLink
		<root>
			<row val="link1" />
			<row val="link2" />
		</root>
	* @LicService: List of Services
		Format:
				<root>
					<row pid="1" val="kathy.nguyen" />
					<row pid="2" val="password" />
					<row pid="3" val="http:..." />
					<row pid="4" val="http:..." />
				</root>
	* @LicLanguage, @LicLanguageSB
		Format:
				<root>
					<row id="1" />
					<row id="2" />
				</root>
	* @CurrenciesOffered, @LicTargetMarket, @LicRestrictCountry: 1,2,3
	
	* @ErrCode:
		= 0: 
		> 0: Specific Error.
  
	* @ErrMsg: Error description.
 */
BEGIN
	SET NOCOUNT ON
	
	-- Insert Licensee
	BEGIN TRY
		INSERT INTO dbo.Licensee (
			LicenseeName
			,LicenseeTypeId
			,LicenseeCompanyName
			,LicenseeStatusId
			,SoftLaunch
			,FullLaunch
			,MainUrl
			,APILinkageUrl
			,LicenseeLocationId
			,RestrictedLocationRemark
			,Remark
			,IsChineseMarketOnly
			,IsReseller
			)
		VALUES(
			@SiteName
			,@LicenseeTypeId
			,@CompanyName
			,@LicenseeStatusId
			,@SoftLaunch
			,@FullLaunch
			,@MainUrl
			,@APIUrl
			,@LocationId		
			,@RestrictCountryRemark	
			,@Remark
			,@IsChineseMarketOnly
			,@IsReseller
		)
	
		SET @LicenseeId = SCOPE_IDENTITY()
		
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 100
		RETURN
	END CATCH
	
	-- Insert Backup Url
	IF @LicBackUpLink IS NOT NULL
	BEGIN
		INSERT INTO dbo.UrlBackup(
				LicenseeId
				,UrlValue
				,[Order]
		)
		SELECT	@LicenseeId
				,t.c.value('@val', 'varchar(3000)')
				, ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS rownumber
		FROM @LicBackUpLink.nodes('root/row') t(c)
		
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 101
			RETURN
		END
	END
	
	-- Insert Main Contact
	IF @HasMainContact = 1
	BEGIN
		INSERT INTO dbo.Contact (
				LicenseeID
				,ContactName
				,ContactPosition
				,ContactDepartment
				,ContactEmail
				,ContactSkype
				,ContactPhoneNumber
				,ContactType
				,Remark
				,IsMain
		)
		SELECT @LicenseeId
				,@MainContactName
				,@Position
				,@Department
				,@Email
				,@Skype
				,@PhoneNumber
				,0
				,@MainContactRemark
				,1
		
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 102
			RETURN
		END
	END
	
	-- Insert currencies offered
	IF @CurrenciesOffered IS NOT NULL
	BEGIN
		INSERT INTO dbo.LicenseeCurrency (LicenseeId, CurrencyId)
		SELECT @LicenseeId, CONVERT(INT, s.val)
		FROM dbo.strSplit(@CurrenciesOffered, ',') s 
		
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 103
			RETURN
		END
	END
	
	-- Insert targeted market
	IF @LicTargetMarket IS NOT NULL
	BEGIN
		INSERT INTO dbo.LicenseeLocationLimit (LicenseeId, LocationLimitId, LicenseeLocationType)
		SELECT @LicenseeId, CONVERT(INT, s.val), 1
		FROM dbo.strSplit(@LicTargetMarket,',') s
		
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 104
			RETURN
		END
	END
	
	-- Insert prefer comunicate language
	IF @LicLanguage IS NOT NULL
	BEGIN
		INSERT INTO dbo.LicenseeLanguage (
				LicenseeId
				,LanguageId
		)		
		SELECT	@LicenseeId
				,t.c.value('@id','int')
		FROM @LicLanguage.nodes('root/row') t(c)
		
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 105
			RETURN
		END
	END
	
	-- Insert service included
	IF @LicService IS NOT NULL
	BEGIN
		INSERT INTO dbo.LicenseeProperty (
				LicenseeId
				,PropertyId
				,PropertyValue
		)
		SELECT	@LicenseeId
				,t.c.value('@pid', 'tinyint') AS Propertyid
	  			,t.c.value('@val', 'varchar(3000)') AS Value
		FROM @LicService.nodes('/root/row') AS t(c)	
	
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 106
			RETURN
		END
	END
	
	-- Insert country restrict		
	IF @LicRestrictCountry IS NOT NULL
	BEGIN
		
		INSERT INTO dbo.LicenseeLocationLimit (LicenseeId, LocationLimitId, LicenseeLocationType)
		SELECT @LicenseeId, CONVERT(INT, s.val), 2
		FROM dbo.strSplit(@LicRestrictCountry, ',') s	
		
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 107
			RETURN
		END
	END

	-- Insert Sportbook offered language
	IF @LicLanguageSB IS NOT NULL
	BEGIN
		INSERT INTO dbo.LicenseeProductLanguage (
				LicenseeId
				,LanguageId
		)		
		SELECT	@LicenseeId
				,t.c.value('@id','int')
		FROM @LicLanguageSB.nodes('root/row') t(c)
		
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 108
			RETURN
		END
	END

	SELECT @ErrCode = 0
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeInfoIns_Step1_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OIC_LicenseeInfoIns_Step1_xtest]
	@UserId					INT
	,@LicenseeTypeId		TINYINT
	,@SiteName				NVARCHAR(50)
	,@CompanyName			NVARCHAR(50)	= NULL
	,@LicenseeStatusId		TINYINT
	,@IsReseller			BIT				= 0
	,@IsChineseMarketOnly	BIT				= 0
	,@SoftLaunch			DATETIME		= NULL
	,@FullLaunch			DATETIME		= NULL
	,@MainUrl				VARCHAR(3000)	= NULL
	,@APIUrl				VARCHAR(3000)	= NULL
	,@LicBackUpLink			XML				= NULL
	,@HasMainContact		BIT				= 0 -- has main contact info
	,@MainContactName		NVARCHAR(50)	= NULL
	,@Position				NVARCHAR(50)	= NULL
	,@Department			NVARCHAR(50)	= NULL
	,@Email					VARCHAR(50)		= NULL
	,@PhoneNumber			VARCHAR(50)		= NULL
	,@Skype					VARCHAR(50)		= NULL
	,@MainContactRemark		NVARCHAR(300)	= NULL
	,@LocationId			INT				= NULL
	,@CurrenciesOffered		VARCHAR(100)	= NULL
	,@LicTargetMarket		VARCHAR(1000)	= NULL
	,@LicLanguage			XML				= NULL
	,@LicLanguageSB			XML				= NULL
	,@LicService			XML				= NULL
	,@LicRestrictCountry	VARCHAR(1000)	= NULL
	,@RestrictCountryRemark	NVARCHAR(2000)	= NULL		
	,@Remark				NVARCHAR(300)	= NULL
	
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
	
	,@LicenseeId			INT				= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2014-12-18
	Task: Insert client general info - Step1 [Redmine:#27752]
	DB: DBOIC/BODB_OIC 
	
	Revisions:
		- 20160805@Percy: Expand length of params: @LicTargetMarket, @LicRestrictCountry [RedmineID: #62099]
		- 20160823@Percy: Add param: @LicLanguageSB - Sportbook offered language [RedmineID: #62883]
		- 20170517@Percy: Add Chinese Market Only [RedmineID: #74330]
		- 20170809@Percy: Extend Url length [RedmineID: #81392]
		- 20170828@Scofield: Add Reseller [#82144]
	
	Param's Explanation:
	* @LicBackupLink
		<root>
			<row val="link1" />
			<row val="link2" />
		</root>
	* @LicService: List of Services
		Format:
				<root>
					<row pid="1" val="kathy.nguyen" />
					<row pid="2" val="password" />
					<row pid="3" val="http:..." />
					<row pid="4" val="http:..." />
				</root>
	* @LicLanguage, @LicLanguageSB
		Format:
				<root>
					<row id="1" />
					<row id="2" />
				</root>
	* @CurrenciesOffered, @LicTargetMarket, @LicRestrictCountry: 1,2,3
	
	* @ErrCode:
		= 0: 
		> 0: Specific Error.
  
	* @ErrMsg: Error description.
 */
BEGIN
	SET NOCOUNT ON
	
	-- Insert Licensee
	BEGIN TRY
		INSERT INTO dbo.Licensee (
			LicenseeName
			,LicenseeTypeId
			,LicenseeCompanyName
			,LicenseeStatusId
			,SoftLaunch
			,FullLaunch
			,MainUrl
			,APILinkageUrl
			,LicenseeLocationId
			,RestrictedLocationRemark
			,Remark
			,IsChineseMarketOnly
			,IsReseller
			)
		VALUES(
			@SiteName
			,@LicenseeTypeId
			,@CompanyName
			,@LicenseeStatusId
			,@SoftLaunch
			,@FullLaunch
			,@MainUrl
			,@APIUrl
			,@LocationId		
			,@RestrictCountryRemark	
			,@Remark
			,@IsChineseMarketOnly
			,@IsReseller
		)
	
		SET @LicenseeId = SCOPE_IDENTITY()
		
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 100
		RETURN
	END CATCH
	
	-- Insert Backup Url
	IF @LicBackUpLink IS NOT NULL
	BEGIN
		INSERT INTO dbo.UrlBackup(
				LicenseeId
				,UrlValue
				,[Order]
		)
		SELECT	@LicenseeId
				,t.c.value('@val', 'varchar(3000)')
				, ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS rownumber
		FROM @LicBackUpLink.nodes('root/row') t(c)
		
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 101
			RETURN
		END
	END
	
	-- Insert Main Contact
	IF @HasMainContact = 1
	BEGIN
		INSERT INTO dbo.Contact (
				LicenseeID
				,ContactName
				,ContactPosition
				,ContactDepartment
				,ContactEmail
				,ContactSkype
				,ContactPhoneNumber
				,ContactType
				,Remark
				,IsMain
		)
		SELECT @LicenseeId
				,@MainContactName
				,@Position
				,@Department
				,@Email
				,@Skype
				,@PhoneNumber
				,0
				,@MainContactRemark
				,1
		
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 102
			RETURN
		END
	END
	
	-- Insert currencies offered
	IF @CurrenciesOffered IS NOT NULL
	BEGIN
		INSERT INTO dbo.LicenseeCurrency (LicenseeId, CurrencyId)
		SELECT @LicenseeId, CONVERT(INT, s.val)
		FROM dbo.strSplit(@CurrenciesOffered, ',') s 
		
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 103
			RETURN
		END
	END
	
	-- Insert targeted market
	IF @LicTargetMarket IS NOT NULL
	BEGIN
		INSERT INTO dbo.LicenseeLocationLimit (LicenseeId, LocationLimitId, LicenseeLocationType)
		SELECT @LicenseeId, CONVERT(INT, s.val), 1
		FROM dbo.strSplit(@LicTargetMarket,',') s
		
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 104
			RETURN
		END
	END
	
	-- Insert prefer comunicate language
	IF @LicLanguage IS NOT NULL
	BEGIN
		INSERT INTO dbo.LicenseeLanguage (
				LicenseeId
				,LanguageId
		)		
		SELECT	@LicenseeId
				,t.c.value('@id','int')
		FROM @LicLanguage.nodes('root/row') t(c)
		
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 105
			RETURN
		END
	END
	
	-- Insert service included
	IF @LicService IS NOT NULL
	BEGIN
		INSERT INTO dbo.LicenseeProperty (
				LicenseeId
				,PropertyId
				,PropertyValue
		)
		SELECT	@LicenseeId
				,t.c.value('@pid', 'tinyint') AS Propertyid
	  			,t.c.value('@val', 'varchar(3000)') AS Value
		FROM @LicService.nodes('/root/row') AS t(c)	
	
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 106
			RETURN
		END
	END
	
	-- Insert country restrict		
	IF @LicRestrictCountry IS NOT NULL
	BEGIN
		
		INSERT INTO dbo.LicenseeLocationLimit (LicenseeId, LocationLimitId, LicenseeLocationType)
		SELECT @LicenseeId, CONVERT(INT, s.val), 2
		FROM dbo.strSplit(@LicRestrictCountry, ',') s	
		
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 107
			RETURN
		END
	END

	-- Insert Sportbook offered language
	IF @LicLanguageSB IS NOT NULL
	BEGIN
		INSERT INTO dbo.LicenseeProductLanguage (
				LicenseeId
				,LanguageId
		)		
		SELECT	@LicenseeId
				,t.c.value('@id','int')
		FROM @LicLanguageSB.nodes('root/row') t(c)
		
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 108
			RETURN
		END
	END

	SELECT @ErrCode = 0
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeInfoIns_Step2]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeInfoIns_Step2    Script Date: 11/21/2016 10:54:03 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeInfoIns_Step2    Script Date: 11/11/2016 10:29:58 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeInfoIns_Step2]
	@UserId					INT
	,@LicenseeId			INT
	,@LicProduct			XML				= NULL
	,@LicFeature			XML				= NULL
	
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2014-12-22
	Task: Registered product & feature - Step2  [Redmine:#27752]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160511@Percy: Change type of input param @LicFeature [RedmineID: #56935]
	
	Param's Explanation:
	- @LicProduct, @LicFeature: list of product, feature
				<root>
					<row id="1" launchdate="2014-12-19" terminationdate="2016-05-11"/>
					<row id="3" launchdate="2014-12-19"/>
				</root>
	
	- @ErrCode:
		= 0: 
		> 0: Specific Error.
  
	- @ErrMsg: Error description.
 */
BEGIN
	SET NOCOUNT ON
	
	-- Insert product
	IF @LicProduct IS NOT NULL
	BEGIN
		INSERT INTO dbo.LicenseeProduct(
				LicenseeId
				,ProductId
				,LaunchDate
				,TerminationDate
		)
		SELECT	@LicenseeId
				,t.c.value('@id','int') AS ProductId
				,t.c.value('@launchdate', 'datetime') AS LaunchDate
				,t.c.value('@terminationdate', 'datetime') AS TerminationDate
		FROM @LicProduct.nodes('root/row') t(c)
	
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 100
			RETURN
		END
	END
	
	-- Insert feature
	IF @LicFeature IS NOT NULL
	BEGIN
		INSERT INTO dbo.LicenseeFeature(
				LicenseeId
				,FeatureId
				,LaunchDate
				,TerminationDate
		)
		SELECT	@LicenseeId
				,t.c.value('@id','int') AS FeatureId
				,t.c.value('@launchdate', 'datetime') AS LaunchDate
				,t.c.value('@terminationdate', 'datetime') AS TerminationDate
		FROM @LicFeature.nodes('root/row') t(c)
	
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 101
			RETURN
		END
	END

	SELECT @ErrCode = 0
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeInfoIns_Step2_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeInfoIns_Step2_xtest    Script Date: 11/11/2016 10:29:58 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeInfoIns_Step2_xtest]
	@UserId					INT
	,@LicenseeId			INT
	,@LicProduct			XML				= NULL
	,@LicFeature			XML				= NULL
	
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2014-12-22
	Task: Registered product & feature - Step2  [Redmine:#27752]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160511@Percy: Change type of input param @LicFeature [RedmineID: #56935]
	
	Param's Explanation:
	- @LicProduct, @LicFeature: list of product, feature
				<root>
					<row id="1" launchdate="2014-12-19" terminationdate="2016-05-11"/>
					<row id="3" launchdate="2014-12-19"/>
				</root>
	
	- @ErrCode:
		= 0: 
		> 0: Specific Error.
  
	- @ErrMsg: Error description.
 */
BEGIN
	SET NOCOUNT ON
	
	-- Insert product
	IF @LicProduct IS NOT NULL
	BEGIN
		INSERT INTO dbo.LicenseeProduct(
				LicenseeId
				,ProductId
				,LaunchDate
				,TerminationDate
		)
		SELECT	@LicenseeId
				,t.c.value('@id','int') AS ProductId
				,t.c.value('@launchdate', 'datetime') AS LaunchDate
				,t.c.value('@terminationdate', 'datetime') AS TerminationDate
		FROM @LicProduct.nodes('root/row') t(c)
	
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 100
			RETURN
		END
	END
	
	-- Insert feature
	IF @LicFeature IS NOT NULL
	BEGIN
		INSERT INTO dbo.LicenseeFeature(
				LicenseeId
				,FeatureId
				,LaunchDate
				,TerminationDate
		)
		SELECT	@LicenseeId
				,t.c.value('@id','int') AS FeatureId
				,t.c.value('@launchdate', 'datetime') AS LaunchDate
				,t.c.value('@terminationdate', 'datetime') AS TerminationDate
		FROM @LicFeature.nodes('root/row') t(c)
	
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 101
			RETURN
		END
	END

	SELECT @ErrCode = 0
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeInfoIns_Step3]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeInfoIns_Step3    Script Date: 8/15/2017 4:11:00 AM ******/
CREATE PROCEDURE [dbo].[OIC_LicenseeInfoIns_Step3]
	@UserId				INT
	,@LicenseeId		INT
	,@AMUserId			INT				
	,@PMUserId			INT				
	,@LicAccount		XML				= NULL
	,@InternalURL		VARCHAR(3000)	= NULL
	
	,@Language			VARCHAR(10)		= 'E'
	,@IP				VARCHAR(50)		= NULL
	,@ErrCode			INT				= 0			OUTPUT
	,@ErrMsg			VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2014-12-22
	Task: Internal Person in Charge - Step3 [Redmine:#27752]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20170517@Percy: Add Internal backend URL [RedmineID: #74330]
		- 20170802@Percy: Add Url testing account - add element into @LicAccount [RedmineID: #80712]
		- 20170809@Percy: Extend Url length [RedmineID: #81392]
	
	Param's Explanation:
	* @LicAccount:
				<root>
					<row order="1" type="1" username="webaccount" password="abc" url="https://" />
					<row order="1" type="2" username="csd" password="1234" url="https://" />
					<row order="1" type="3" username="training" password="12abc" url="https://" />
				</root>
	* @ErrCode:
		= 0: 
		> 0: Specific Error.
  
	* @ErrMsg: Error description.
 */
BEGIN
	SET NOCOUNT ON

	-- Internal Backend URL
	UPDATE dbo.Licensee WITH(ROWLOCK, UPDLOCK)
	SET InternalURL = @InternalURL
	WHERE LicenseeId = @LicenseeId

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 100
		RETURN
	END
	
	-- Insert AM
	INSERT INTO dbo.UserLicensee(UserId, LicenseeId) VALUES (@AMUserId, @LicenseeId)
	
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 100
		RETURN
	END
	
	-- Insert PM
	INSERT INTO dbo.UserLicensee(UserId, LicenseeId) VALUES (@PMUserId, @LicenseeId)
	
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 101
		RETURN
	END
	
	-- Insert Account
	IF @LicAccount IS NOT NULL
	BEGIN
		INSERT INTO dbo.LicenseeAccountInfo (
				LicenseeId
				,UserName
				,UserPwd
				,AccountType
				,[Order]
				,Url
		)
		SELECT	@LicenseeId
				,t.c.value('@username','nvarchar(50)')
				,t.c.value('@password','nvarchar(50)')
				,t.c.value('@type','tinyint')
				,t.c.value('@order','tinyint')
				,t.c.value('@url','varchar(3000)')
		FROM @LicAccount.nodes('root/row') t(c) 
		
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 102
			RETURN
		END
	END

	SELECT @ErrCode = 0
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeInfoIns_Step3_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OIC_LicenseeInfoIns_Step3_xtest]
	@UserId				INT
	,@LicenseeId		INT
	,@AMUserId			INT				
	,@PMUserId			INT				
	,@LicAccount		XML				= NULL
	,@InternalURL		VARCHAR(3000)	= NULL
	
	,@Language			VARCHAR(10)		= 'E'
	,@IP				VARCHAR(50)		= NULL
	,@ErrCode			INT				= 0			OUTPUT
	,@ErrMsg			VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2014-12-22
	Task: Internal Person in Charge - Step3 [Redmine:#27752]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20170517@Percy: Add Internal backend URL [RedmineID: #74330]
		- 20170802@Percy: Add Url testing account - add element into @LicAccount [RedmineID: #80712]
		- 20170809@Percy: Extend Url length [RedmineID: #81392]
	
	Param's Explanation:
	* @LicAccount:
				<root>
					<row order="1" type="1" username="webaccount" password="abc" url="https://" />
					<row order="1" type="2" username="csd" password="1234" url="https://" />
					<row order="1" type="3" username="training" password="12abc" url="https://" />
				</root>
	* @ErrCode:
		= 0: 
		> 0: Specific Error.
  
	* @ErrMsg: Error description.
 */
BEGIN
	SET NOCOUNT ON

	-- Internal Backend URL
	UPDATE dbo.Licensee WITH(ROWLOCK, UPDLOCK)
	SET InternalURL = @InternalURL
	WHERE LicenseeId = @LicenseeId

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 100
		RETURN
	END
	
	-- Insert AM
	INSERT INTO dbo.UserLicensee(UserId, LicenseeId) VALUES (@AMUserId, @LicenseeId)
	
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 100
		RETURN
	END
	
	-- Insert PM
	INSERT INTO dbo.UserLicensee(UserId, LicenseeId) VALUES (@PMUserId, @LicenseeId)
	
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 101
		RETURN
	END
	
	-- Insert Account
	IF @LicAccount IS NOT NULL
	BEGIN
		INSERT INTO dbo.LicenseeAccountInfo (
				LicenseeId
				,UserName
				,UserPwd
				,AccountType
				,[Order]
				,Url
		)
		SELECT	@LicenseeId
				,t.c.value('@username','nvarchar(50)')
				,t.c.value('@password','nvarchar(50)')
				,t.c.value('@type','tinyint')
				,t.c.value('@order','tinyint')
				,t.c.value('@url','varchar(3000)')
		FROM @LicAccount.nodes('root/row') t(c) 
		
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 102
			RETURN
		END
	END

	SELECT @ErrCode = 0
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeInfoIns_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OIC_LicenseeInfoIns_xtest]
	@UserId					INT
	,@LicenseeTypeId		TINYINT
	,@SiteName				NVARCHAR(50)
	,@CompanyName			NVARCHAR(50)	= NULL
	,@LicenseeStatusId		TINYINT
	,@IsReseller			BIT				= 0
	,@IsChineseMarketOnly	BIT				= 0
	,@SoftLaunch			DATETIME		= NULL
	,@FullLaunch			DATETIME		= NULL
	,@MainUrl				VARCHAR(3000)	= NULL
	,@APIUrl				VARCHAR(3000)	= NULL
	,@LicBackUpLink			XML				= NULL
	,@HasMainContact		BIT				= 0 -- has main contact info
	,@MainContactName		NVARCHAR(50)	= NULL
	,@Position				NVARCHAR(50)	= NULL
	,@Department			NVARCHAR(50)	= NULL
	,@Email					VARCHAR(50)		= NULL
	,@PhoneNumber			VARCHAR(50)		= NULL
	,@Skype					VARCHAR(50)		= NULL
	,@MainContactRemark		NVARCHAR(300)	= NULL
	,@LocationId			INT				= NULL
	,@CurrenciesOffered		VARCHAR(100)	= NULL
	,@LicTargetMarket		VARCHAR(1000)	= NULL
	,@LicLanguage			XML				= NULL
	,@LicLanguageSB			XML				= NULL
	,@LicService			XML				= NULL
	,@LicRestrictCountry	VARCHAR(1000)	= NULL
	,@RestrictCountryRemark	NVARCHAR(2000)	= NULL		
	,@Remark				NVARCHAR(300)	= NULL
	,@LicProduct			XML				= NULL
	,@LicFeature			XML				= NULL
	,@AMUserId				INT				
	,@PMUserId				INT				
	,@LicAccount			XML				= NULL
	,@InternalURL			VARCHAR(3000)	= NULL
	
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2014-12-18
	Task: Insert Licensee [Redmine:#27752]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160511@Percy: Change type of input param @LicFeature [RedmineID: #56935]
		- 20160805@Percy: Expand length of params: @LicTargetMarket, @LicRestrictCountry [RedmineID: #62099]
		- 20160823@Percy: Add param: @LicLanguageSB - Sportbook offered language [RedmineID: #62883]
		- 20170517@Percy: Add Chinese Market Only and Internal Backend URL [RedmineID: #74330]
		- 20170802@Percy: Add Url testing account - add element into @LicAccount [RedmineID: #80712]
		- 20170809@Percy: Extend Url length [RedmineID: #81392]
		- 20170828@Scofield: Add Reseller [#82144]
	
	Param's Explanation:
	* @LicBackupLink
		<root>
			<row val="link1" />
			<row val="link2" />
		</root>
	* @LicService: List of Services
		Format:
				<root>
					<row pid="1" val="kathy.nguyen" />
					<row pid="2" val="password" />
					<row pid="3" val="http:..." />
					<row pid="4" val="http:..." />
				</root>
	* @LicLanguage, @LicLanguageSB
		Format:
				<root>
					<row id="1" />
					<row id="2" />
				</root>
	* @LicProduct, @LicFeature: list of product, feature
				<root>
					<row id="1" launchdate="2014-12-19" terminationdate="2016-05-11"/>
					<row id="3" launchdate="2014-12-19"/>
				</root>
				
	* @LicAccount:
				<root>
					<row order="1" type="1" username="webaccount" password="abc" url="https://" />
					<row order="1" type="2" username="csd" password="1234" url="https://" />
					<row order="1" type="3" username="training" password="12abc" url="https://" />
				</root>
				
	* @CurrenciesOffered, @LicTargetMarket, @LicRestrictCountry
	* @ErrCode:
		= 0: 
		> 0: Specific Error.
  
	* @ErrMsg: Error description.
	
	* Log:
 */
BEGIN
	SET NOCOUNT ON
	
	DECLARE @LicenseeId INT

	-- For write log
	DECLARE 
		@startRun					DATETIME
		,@endRun					DATETIME
		,@duration					INT
		,@logSPData					NVARCHAR(MAX)
		,@xml						XML
		,@procName					VARCHAR(200)
		-- log step 1
		,@log_backupLink			XML
		,@log_maincontact			XML
		,@log_currency				XML
		,@log_targetedMarket		XML
		,@log_restrictedLocation	XML
		,@log_language				XML
		,@log_languageSB			XML
		,@log_service				XML
		-- log step 2
		,@log_product				XML
		,@log_feature				XML
		-- log step 3
		,@log_account				XML

	SET @startRun = GETDATE()
	
	-- check licensee name
	EXEC dbo.OIC_LicenseeNameChecking
		@SiteName	= @SiteName
		,@Language	= @Language
		,@ErrCode	= @ErrCode	OUTPUT
		,@ErrMsg	= @ErrMsg	OUTPUT
	
	IF @ErrCode <> 0
	BEGIN
		SELECT @ErrCode, @ErrMsg
		RETURN
	END
		
	-- Step1: Insert general info
	EXEC dbo.OIC_LicenseeInfoIns_Step1_xtest
		@UserId						= @UserId
		,@LicenseeTypeId			= @LicenseeTypeId
		,@SiteName					= @SiteName
		,@CompanyName				= @CompanyName
		,@LicenseeStatusId			= @LicenseeStatusId
		,@IsReseller				= @IsReseller
		,@IsChineseMarketOnly		= @IsChineseMarketOnly
		,@SoftLaunch				= @SoftLaunch
		,@FullLaunch				= @FullLaunch
		,@MainUrl					= @MainUrl
		,@APIUrl					= @APIUrl
		,@LicBackUpLink				= @LicBackUpLink
		,@HasMainContact			= @HasMainContact -- has main contact info
		,@MainContactName			= @MainContactName
		,@Position					= @Position
		,@Department				= @Department
		,@Email						= @Email
		,@PhoneNumber				= @PhoneNumber
		,@Skype						= @Skype
		,@MainContactRemark			= @MainContactRemark
		,@LocationId				= @LocationId
		,@CurrenciesOffered			= @CurrenciesOffered
		,@LicTargetMarket			= @LicTargetMarket
		,@LicLanguage				= @LicLanguage
		,@LicLanguageSB				= @LicLanguageSB
		,@LicService				= @LicService
		,@LicRestrictCountry		= @LicRestrictCountry
		,@RestrictCountryRemark		= @RestrictCountryRemark		
		,@Remark					= @Remark
		
		,@Language					= @Language
		,@IP						= @IP
		,@ErrCode					= @ErrCode		OUTPUT
		,@ErrMsg					= @ErrMsg		OUTPUT
		
		,@LicenseeId				= @LicenseeId	OUTPUT
	
	
	IF @ErrCode <> 0
	BEGIN
		SELECT	@ErrCode = @ErrCode
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1, @Language) -- Fail to insert data step1
		
		-- Rollback Step1:
		DELETE FROM dbo.Licensee WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.UrlBackup WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.LicenseeCurrency WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.LicenseeLocationLimit WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.LicenseeLanguage  WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.LicenseeProperty  WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.Contact WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeID = @LicenseeId
		-- END rollback Step1
		
		RETURN
	END
	
	-- END step1
	
	-- Step2: Registered product & feature 
	IF @LicProduct IS NOT NULL OR @LicFeature IS NOT NULL
	BEGIN
		EXEC dbo.OIC_LicenseeInfoIns_Step2
		@UserId			= @UserId		
		,@LicenseeId	= @LicenseeId
		,@LicProduct	= @LicProduct
		,@LicFeature	= @LicFeature

		,@Language		= @Language
		,@IP			= @IP
		,@ErrCode		= @ErrCode	OUTPUT
		,@ErrMsg		= @ErrMsg	OUTPUT
		
		IF @ErrCode <> 0
		BEGIN
			SELECT	@ErrCode = @ErrCode
					,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](2, @Language) -- Fail to insert data step2
				
			-- Rollback Step1:
			DELETE FROM dbo.Licensee WITH(ROWLOCK, UPDLOCK)
			WHERE LicenseeId = @LicenseeId
			
			DELETE FROM dbo.UrlBackup WITH(ROWLOCK, UPDLOCK)
			WHERE LicenseeId = @LicenseeId
			
			DELETE FROM dbo.LicenseeCurrency WITH(ROWLOCK, UPDLOCK)
			WHERE LicenseeId = @LicenseeId
			
			DELETE FROM dbo.LicenseeLocationLimit WITH(ROWLOCK, UPDLOCK)
			WHERE LicenseeId = @LicenseeId
			
			DELETE FROM dbo.LicenseeLanguage  WITH(ROWLOCK, UPDLOCK)
			WHERE LicenseeId = @LicenseeId
			
			DELETE FROM dbo.Licensee  WITH(ROWLOCK, UPDLOCK)
			WHERE LicenseeId = @LicenseeId
			-- END rollback Step1
			
			-- Rollback Step2:
			DELETE 
			FROM dbo.LicenseeProduct WITH(ROWLOCK,UPDLOCK)
			WHERE LicenseeId = @LicenseeId
			
			DELETE
			FROM dbo.LicenseeFeature WITH(ROWLOCK, UPDLOCK)
			WHERE LicenseeId = @LicenseeId
			-- END rollback Step2	
			
			RETURN
			
		END
	END	
	-- END Step2
	
	-- Step3: Internal Person in Charge 
	EXEC dbo.OIC_LicenseeInfoIns_Step3
		@UserId				= @UserId
		,@LicenseeId		= @LicenseeId
		,@AMUserId			= @AMUserId
		,@PMUserId			= @PMUserId
		,@LicAccount		= @LicAccount
		,@Language			= @Language
		,@IP				= @IP
		,@InternalURL		= @InternalURL

		,@ErrCode			= @ErrCode	OUTPUT
		,@ErrMsg			= @ErrMsg	OUTPUT
		
	IF @ErrCode <> 0
	BEGIN
		SELECT	@ErrCode = @ErrCode
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](3, @Language) -- Fail to insert data step3
			
		-- Rollback Step1:
		DELETE FROM dbo.Licensee WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.UrlBackup WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.LicenseeCurrency WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.LicenseeLocationLimit WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.LicenseeLanguage  WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.LicenseeProperty  WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		-- END rollback Step1
		
		-- Rollback Step2:
		DELETE 
		FROM dbo.LicenseeProduct WITH(ROWLOCK,UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE
		FROM dbo.LicenseeFeature WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		-- END rollback Step2
		
		-- Rollback data Step3:
		DELETE FROM dbo.LicenseeAccountInfo WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		
		DELETE FROM dbo.UserLicensee  WITH(ROWLOCK, UPDLOCK)
		WHERE LicenseeId = @LicenseeId
		-- END rollback Step3
		
		RETURN
	END
	--END Step3

	-- write log
	SET @log_backupLink = (
							SELECT	lu.UrlValue AS '@lbul'
							FROM dbo.UrlBackup AS lu WITH (NOLOCK)
							WHERE	lu.LicenseeId = @LicenseeId
							FOR XML PATH('row'), ROOT('bk')		
						)
						
	SET @log_maincontact = (SELECT	c.ContactID			AS '@cid'
									,c.ContactName		AS '@cn'
									,c.ContactPosition	AS '@cp'
									,c.ContactDepartment AS '@cd'
									,c.ContactEmail		AS '@ce'
									,c.ContactSkype		AS '@cs'
									,c.ContactPhoneNumber	AS '@cpn'
									,c.IsMain			AS '@cim'
									,c.Remark			AS '@crm'
							FROM	dbo.Contact c
							WHERE	licenseeid = @LicenseeId AND c.IsMain = 1
							FOR XML PATH('row'), ROOT('lc')	
						)
	
	SET @log_currency = (
							SELECT	e.exchangeid AS '@cid'
									,e.Code AS '@cur'
							FROM dbo.LicenseeCurrency AS lc WITH (NOLOCK)
								INNER JOIN bodb02.dbo.Exchange AS e WITH(NOLOCK) 
									ON e.exchangeid = lc.CurrencyId
							WHERE	lc.LicenseeId = @LicenseeId
							FOR XML PATH('row'), ROOT('cr')	
						)
						
	SET @log_targetedMarket = (
							SELECT  lo.LocationId AS '@tmid'
									,lo.LocationName AS '@tmn'
							FROM dbo.LicenseeLocationLimit AS ll WITH (NOLOCK)
								INNER JOIN dbo.Location AS lo WITH(NOLOCK) 
									ON lo.LocationId = ll.LocationLimitId 
									AND ll.LicenseeLocationType = 1
							WHERE	ll.LicenseeId = @LicenseeId
							FOR XML PATH('row'), ROOT('tm')	
						)
	SET @log_restrictedLocation = (
							SELECT lo.LocationId AS '@rlid'
									,lo.LocationName AS '@rln'
							FROM dbo.LicenseeLocationLimit AS ll WITH (NOLOCK)
								INNER JOIN dbo.Location AS lo WITH(NOLOCK) 
									ON lo.LocationId = ll.LocationLimitId 
									AND ll.LicenseeLocationType = 2
							WHERE	ll.LicenseeId = @LicenseeId
							FOR XML PATH('row'), ROOT('rl')		
						)
						
	SET @log_Language = (
							SELECT	la.LanguageId AS '@llid'
									,la.LanguageName AS '@lln'
							FROM dbo.LicenseeLanguage AS ll WITH (NOLOCK)
								INNER JOIN dbo.Language AS la WITH(NOLOCK) 
									ON la.LanguageId = ll.LanguageId
							WHERE	ll.LicenseeId = @LicenseeId
							FOR XML PATH('row'), ROOT('ll')	
						)
						
	SET @log_languageSB = (
							SELECT	la.LanguageId AS '@llidsb'
									,la.LanguageName AS '@llnsb'
							FROM dbo.LicenseeProductLanguage AS ll WITH (NOLOCK)
								INNER JOIN dbo.Language AS la WITH(NOLOCK) 
									ON la.LanguageId = ll.LanguageId
							WHERE	ll.LicenseeId = @LicenseeId
							FOR XML PATH('row'), ROOT('llsb')	
						)

	SET @log_service = (	SELECT	s.ServiceId				AS '@lsid'
									,s.ServiceName				AS '@lsn'
									,p.PropertyId				as '@lspid'
									,lp.PropertyValue as '@lspv'
							FROM dbo.LicenseeProperty lp
								INNER JOIN dbo.Property p 
									ON	p.PropertyId = lp.PropertyId
								INNER JOIN dbo.Service s 
									ON	s.ServiceId = p.ServiceId
							WHERE	licenseeid = @LicenseeId
							FOR XML PATH('row'), ROOT('ls')	
						)
	SET @log_product = (	SELECT	p.ProductId AS '@lpid'
									,p.ProductName AS '@lpn'
									,p.[Order] AS '@lpod'
									,lp.LaunchDate AS '@lpl'
									,lp.TerminationDate AS '@lpt'
							FROM dbo.LicenseeProduct AS lp WITH (NOLOCK)
								INNER JOIN dbo.Product AS p WITH(NOLOCK) 
									ON	p.ProductId = lp.ProductId
							WHERE	lp.LicenseeId = @LicenseeId
							FOR XML PATH('row'), ROOT('lp')	
						)
	SET @log_feature = (	SELECT	f.FeatureId AS '@lfid'
									,f.FeatureName AS '@lfn'
									,lf.LaunchDate AS '@lfl'
									,lf.TerminationDate AS '@lft'
							FROM dbo.LicenseeFeature AS lf WITH (NOLOCK)
								INNER JOIN dbo.Feature AS f WITH(NOLOCK) 
									ON	f.FeatureId = lf.FeatureId
							WHERE	lf.LicenseeId = @LicenseeId
							FOR XML PATH('row'), ROOT('lf')	
						)
	SET @log_account = (	SELECT	la.AccountId AS '@laid'
									,la.UserName AS '@lan'
									,la.UserPwd AS '@lap'
									,la.AccountType AS '@lat'
									,la.[Order] AS '@lod'
									,la.Url AS '@lu'
							FROM dbo.LicenseeAccountInfo la WITH (NOLOCK)
							WHERE la.LicenseeId = @LicenseeId
							FOR XML PATH('row'), ROOT('la')	
						)
	
	DECLARE @pmn NVARCHAR(100), @amn NVARCHAR(100), @location NVARCHAR(50)
	
	SELECT  @pmn = pui.DisplayName
	FROM dbo.UserLicensee pul WITH(NOLOCK)
		INNER JOIN dbo.UserInfo pui WITH(NOLOCK) ON pul.UserId = pui.UserId AND pui.PositionId = 5 AND pul.LicenseeId = @LicenseeId
	
	SELECT  @amn = pui.DisplayName
	FROM dbo.UserLicensee pul WITH(NOLOCK)
		INNER JOIN dbo.UserInfo pui WITH(NOLOCK) ON pul.UserId = pui.UserId AND pui.PositionId = 6 AND pul.LicenseeId = @LicenseeId
	
	SELECT @location = LocationName FROM dbo.Location WITH(NOLOCK) WHERE LocationId = @LocationId

	-- Write log
	SET @xml = (
		SELECT	@LicenseeId					AS '@lid'
				,t.LicenseeTypeName			AS '@tn'
				,l.LicenseeName				AS '@ln'
				,l.LicenseeCompanyName		AS '@cn'
				,s.LicenseeStatusName		AS '@sn'
				,l.SoftLaunch				AS '@sl'
				,l.FullLaunch				AS '@fl'
				,l.MainUrl					AS '@mu'
				,l.APILinkageUrl			AS '@au'
				,l.RestrictedLocationRemark	AS '@rlr'			
				,l.Remark					AS '@rm'
				,l.IsChineseMarketOnly		AS '@icm'
				,l.IsReseller				AS '@res'
				,l.InternalURL				AS '@iu'
				,@location					AS '@lc'
				,@pmn						AS '@pmn'
				,@amn						AS '@amn'
				,@log_backupLink
				,@log_maincontact
				,@log_currency
				,@log_Language
				,@log_LanguageSB
				,@log_restrictedLocation
				,@log_targetedMarket
				,@log_service
				,@log_product
				,@log_feature
				,@log_account
		FROM dbo.Licensee AS l WITH (NOLOCK)
			INNER JOIN dbo.LicenseeStatus AS s WITH(NOLOCK) ON l.LicenseeStatusId = s.LicenseeStatusId
			INNER JOIN dbo.LicenseeType AS t WITH(NOLOCK) ON l.LicenseeTypeId = t.LicenseeTypeId
		WHERE l.LicenseeId = @LicenseeId
		FOR XML PATH('r'), TYPE)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeInfoSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeInfoSel    Script Date: 9/11/2017 11:37:11 PM ******/
CREATE PROCEDURE [dbo].[OIC_LicenseeInfoSel]	
	@LicenseeId		INT
	,@Step			TINYINT	= 1
AS
/*
	Created by: Kathy
	Date: 20150505
	Task: Select licensee info [Redmine:#30959]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160513@Percy: Add field TerminationDate [RedmineID: #56935]
		- 20160805@Percy: Expand length of params: @LicTargetMarket, @LicRestrictCountry [RedmineID: #62099]
		- 20160823@Percy: Return param: @LicLanguageSB - column: SBOfferedLanguage - Sportbook offered language [RedmineID: #62883]
		- 20170517@Percy: Return Chinese Market Only and Internal Backend URL [RedmineID: #74330]
		- 20170802@Percy: Return Url testing account [RedmineID: #80712]
		- 20170828@Scofield: Add Reseller [#82144]
	
	Param's Explanation:
		@Step: 1,2,3

 */
BEGIN
	SET NOCOUNT ON
	
	DECLARE @LicBackupLink			XML
			,@OfferedCurrencies		VARCHAR(100)
			,@LicTargetMarket		VARCHAR(1000)
			,@LicLanguage			XML
			,@LicLanguageSB			XML
			,@LicService			XML
			,@LicRestrictCountry	VARCHAR(1000)
			,@PMUserId				INT
			,@AMUserId				INT
			,@LicAccount			XML
			
	IF @Step = 1
	BEGIN
		SET @LicBackupLink = (
								SELECT	lu.UrlValue		AS '@val'
								FROM	dbo.UrlBackup	AS lu WITH (NOLOCK)
								WHERE	lu.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('root')		
							)
		
		SELECT	@OfferedCurrencies = COALESCE(@OfferedCurrencies + ',' + CONVERT(VARCHAR(10),CurrencyId), CONVERT(VARCHAR(10),CurrencyId)) 
		FROM	dbo.LicenseeCurrency WITH(NOLOCK)
		WHERE	LicenseeId = @LicenseeId
		
		SELECT	@LicTargetMarket = COALESCE(@LicTargetMarket + ',' + CONVERT(VARCHAR(10),LocationLimitId), CONVERT(VARCHAR(10),LocationLimitId)) 
		FROM	dbo.LicenseeLocationLimit WITH(NOLOCK)
		WHERE	LicenseeId = @LicenseeId
				AND LicenseeLocationType = 1
				
		SELECT	@LicRestrictCountry = COALESCE(@LicRestrictCountry + ',' + CONVERT(VARCHAR(10),LocationLimitId), CONVERT(VARCHAR(10),LocationLimitId)) 
		FROM	dbo.LicenseeLocationLimit WITH(NOLOCK)
		WHERE	LicenseeId = @LicenseeId
				AND LicenseeLocationType = 2
				
		SET @LicLanguage = (
								SELECT	ll.LanguageId	AS '@id'
								FROM	dbo.LicenseeLanguage AS ll WITH (NOLOCK)
								WHERE	ll.LicenseeId = @LicenseeId AND ll.LanguageId <> 4
								FOR XML PATH('row'), ROOT('root')		
							)
		
		SET @LicLanguageSB = (
								SELECT	ll.LanguageId	AS '@id'
								FROM	dbo.LicenseeProductLanguage AS ll WITH (NOLOCK)
								WHERE	ll.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('root')		
							)
		
		SET @LicService = (
								SELECT	p.ServiceId			AS '@sid'
										,lp.PropertyId		AS '@pid'
										,lp.PropertyValue	AS '@val'
								FROM	dbo.LicenseeProperty lp WITH (NOLOCK)
									INNER JOIN dbo.Property p WITH (NOLOCK)
										ON	p.PropertyId = lp.PropertyId
								WHERE	lp.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('root')		
							)
			
		SELECT	l.LicenseeTypeId
				,l.LicenseeName
				,l.LicenseeCompanyName
				,l.LicenseeStatusId
				,l.SoftLaunch
				,l.FullLaunch
				,l.MainUrl
				,l.APILinkageUrl
				,@LicBackupLink				AS BackUpLink
				,CASE WHEN c.ContactID IS NOT NULL THEN 1 ELSE 0 END AS HasMainContact
				,c.ContactName
				,c.ContactPosition			AS Position
				,c.ContactDepartment		AS Department
				,c.ContactEmail				AS Email
				,c.ContactPhoneNumber		AS PhoneNumber
				,c.ContactSkype				AS Skype
				,c.Remark					AS MainContactRemark
				,@OfferedCurrencies			AS OfferedCurrencies
				,l.LicenseeLocationId
				,@LicTargetMarket			AS TargetedMarket
				,@LicLanguage				AS PreferredLanguage
				,@LicLanguageSB				AS SBOfferedLanguage
				,@LicService				AS ServiceIncluded
				,@LicRestrictCountry		AS RestrictCountry
				,l.RestrictedLocationRemark
				,l.Remark					AS LicenseeRemark
				,l.IsChineseMarketOnly		AS IsChineseMarketOnly
				,l.IsReseller				AS IsReseller
		FROM	dbo.Licensee l WITH(NOLOCK)
			LEFT JOIN dbo.Contact c WITH(NOLOCK) 
				ON	l.LicenseeId = c.LicenseeID AND c.IsMain = 1	
		WHERE	l.LicenseeId = @LicenseeId
	END
	ELSE IF @Step = 2
	BEGIN
		SELECT	p.ProductId
				,p.ProductName
				,lp.LaunchDate
				,lp.TerminationDate
				,CASE WHEN lp.ProductId IS NOT NULL THEN 1 ELSE 0 END AS Selected
		FROM	dbo.Product p WITH(NOLOCK)
			LEFT JOIN dbo.LicenseeProduct lp WITH(NOLOCK)
				ON	p.ProductId = lp.ProductId
					AND lp.LicenseeId = @LicenseeId
		ORDER BY p.[Order]
					
		SELECT f.FeatureId
				,f.FeatureName
				,lf.LaunchDate
				,lf.TerminationDate
				,CASE WHEN lf.FeatureId IS NOT NULL THEN 1 ELSE 0 END AS Selected
		FROM	dbo.Feature f WITH(NOLOCK)
			LEFT JOIN dbo.LicenseeFeature lf WITH(NOLOCK)
				ON	lf.FeatureId = f.FeatureId
					AND lf.LicenseeId = @LicenseeId
		ORDER BY f.FeatureId
	END
	ELSE IF @Step = 3
	BEGIN
		SELECT	@PMUserId = ui.UserId
		FROM	dbo.UserInfo ui WITH(NOLOCK)
			INNER JOIN dbo.UserLicensee ul WITH(NOLOCK)
				ON	ui.UserId = ul.UserId
					AND ui.PositionId = 5 -- PM
					AND ul.LicenseeId = @LicenseeId
					
		SELECT	@AMUserId = ui.UserId
		FROM	dbo.UserInfo ui WITH(NOLOCK)
			INNER JOIN dbo.UserLicensee ul WITH(NOLOCK)
				ON	ui.UserId = ul.UserId
					AND ui.PositionId = 6 -- AM
					AND ul.LicenseeId = @LicenseeId
					
		SET @LicAccount = (
								SELECT	la.[Order]		AS '@order'
										,la.AccountType AS '@type'
										,la.UserName	AS '@username'
										,la.UserPwd		AS '@password'
										,la.Url			AS '@url'
								FROM	dbo.LicenseeAccountInfo AS la WITH (NOLOCK)
								WHERE	la.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('root')		
							)
							
		SELECT @AMUserId		AS AMUser
				,@PMUserId		AS PMUser
				,@LicAccount	AS AccountInfo
				,InternalURL
		FROM dbo.Licensee WITH(NOLOCK)
		WHERE LicenseeId = @LicenseeId
	END
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeInfoSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OIC_LicenseeInfoSel_xtest]	
	@LicenseeId		INT
	,@Step			TINYINT	= 1
AS
/*
	Created by: Kathy
	Date: 20150505
	Task: Select licensee info [Redmine:#30959]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160513@Percy: Add field TerminationDate [RedmineID: #56935]
		- 20160805@Percy: Expand length of params: @LicTargetMarket, @LicRestrictCountry [RedmineID: #62099]
		- 20160823@Percy: Return param: @LicLanguageSB - column: SBOfferedLanguage - Sportbook offered language [RedmineID: #62883]
		- 20170517@Percy: Return Chinese Market Only and Internal Backend URL [RedmineID: #74330]
		- 20170802@Percy: Return Url testing account [RedmineID: #80712]
		- 20170828@Scofield: Add Reseller [#82144]
	
	Param's Explanation:
		@Step: 1,2,3

 */
BEGIN
	SET NOCOUNT ON
	
	DECLARE @LicBackupLink			XML
			,@OfferedCurrencies		VARCHAR(100)
			,@LicTargetMarket		VARCHAR(1000)
			,@LicLanguage			XML
			,@LicLanguageSB			XML
			,@LicService			XML
			,@LicRestrictCountry	VARCHAR(1000)
			,@PMUserId				INT
			,@AMUserId				INT
			,@LicAccount			XML
			
	IF @Step = 1
	BEGIN
		SET @LicBackupLink = (
								SELECT	lu.UrlValue		AS '@val'
								FROM	dbo.UrlBackup	AS lu WITH (NOLOCK)
								WHERE	lu.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('root')		
							)
		
		SELECT	@OfferedCurrencies = COALESCE(@OfferedCurrencies + ',' + CONVERT(VARCHAR(10),CurrencyId), CONVERT(VARCHAR(10),CurrencyId)) 
		FROM	dbo.LicenseeCurrency WITH(NOLOCK)
		WHERE	LicenseeId = @LicenseeId
		
		SELECT	@LicTargetMarket = COALESCE(@LicTargetMarket + ',' + CONVERT(VARCHAR(10),LocationLimitId), CONVERT(VARCHAR(10),LocationLimitId)) 
		FROM	dbo.LicenseeLocationLimit WITH(NOLOCK)
		WHERE	LicenseeId = @LicenseeId
				AND LicenseeLocationType = 1
				
		SELECT	@LicRestrictCountry = COALESCE(@LicRestrictCountry + ',' + CONVERT(VARCHAR(10),LocationLimitId), CONVERT(VARCHAR(10),LocationLimitId)) 
		FROM	dbo.LicenseeLocationLimit WITH(NOLOCK)
		WHERE	LicenseeId = @LicenseeId
				AND LicenseeLocationType = 2
				
		SET @LicLanguage = (
								SELECT	ll.LanguageId	AS '@id'
								FROM	dbo.LicenseeLanguage AS ll WITH (NOLOCK)
								WHERE	ll.LicenseeId = @LicenseeId AND ll.LanguageId <> 4
								FOR XML PATH('row'), ROOT('root')		
							)
		
		SET @LicLanguageSB = (
								SELECT	ll.LanguageId	AS '@id'
								FROM	dbo.LicenseeProductLanguage AS ll WITH (NOLOCK)
								WHERE	ll.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('root')		
							)
		
		SET @LicService = (
								SELECT	p.ServiceId			AS '@sid'
										,lp.PropertyId		AS '@pid'
										,lp.PropertyValue	AS '@val'
								FROM	dbo.LicenseeProperty lp WITH (NOLOCK)
									INNER JOIN dbo.Property p WITH (NOLOCK)
										ON	p.PropertyId = lp.PropertyId
								WHERE	lp.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('root')		
							)
			
		SELECT	l.LicenseeTypeId
				,l.LicenseeName
				,l.LicenseeCompanyName
				,l.LicenseeStatusId
				,l.SoftLaunch
				,l.FullLaunch
				,l.MainUrl
				,l.APILinkageUrl
				,@LicBackupLink				AS BackUpLink
				,CASE WHEN c.ContactID IS NOT NULL THEN 1 ELSE 0 END AS HasMainContact
				,c.ContactName
				,c.ContactPosition			AS Position
				,c.ContactDepartment		AS Department
				,c.ContactEmail				AS Email
				,c.ContactPhoneNumber		AS PhoneNumber
				,c.ContactSkype				AS Skype
				,c.Remark					AS MainContactRemark
				,@OfferedCurrencies			AS OfferedCurrencies
				,l.LicenseeLocationId
				,@LicTargetMarket			AS TargetedMarket
				,@LicLanguage				AS PreferredLanguage
				,@LicLanguageSB				AS SBOfferedLanguage
				,@LicService				AS ServiceIncluded
				,@LicRestrictCountry		AS RestrictCountry
				,l.RestrictedLocationRemark
				,l.Remark					AS LicenseeRemark
				,l.IsChineseMarketOnly		AS IsChineseMarketOnly
				,l.IsReseller				AS IsReseller
		FROM	dbo.Licensee l WITH(NOLOCK)
			LEFT JOIN dbo.Contact c WITH(NOLOCK) 
				ON	l.LicenseeId = c.LicenseeID AND c.IsMain = 1	
		WHERE	l.LicenseeId = @LicenseeId
	END
	ELSE IF @Step = 2
	BEGIN
		SELECT	p.ProductId
				,p.ProductName
				,lp.LaunchDate
				,lp.TerminationDate
				,CASE WHEN lp.ProductId IS NOT NULL THEN 1 ELSE 0 END AS Selected
		FROM	dbo.Product p WITH(NOLOCK)
			LEFT JOIN dbo.LicenseeProduct lp WITH(NOLOCK)
				ON	p.ProductId = lp.ProductId
					AND lp.LicenseeId = @LicenseeId
		ORDER BY p.[Order]
					
		SELECT f.FeatureId
				,f.FeatureName
				,lf.LaunchDate
				,lf.TerminationDate
				,CASE WHEN lf.FeatureId IS NOT NULL THEN 1 ELSE 0 END AS Selected
		FROM	dbo.Feature f WITH(NOLOCK)
			LEFT JOIN dbo.LicenseeFeature lf WITH(NOLOCK)
				ON	lf.FeatureId = f.FeatureId
					AND lf.LicenseeId = @LicenseeId
		ORDER BY f.FeatureId
	END
	ELSE IF @Step = 3
	BEGIN
		SELECT	@PMUserId = ui.UserId
		FROM	dbo.UserInfo ui WITH(NOLOCK)
			INNER JOIN dbo.UserLicensee ul WITH(NOLOCK)
				ON	ui.UserId = ul.UserId
					AND ui.PositionId = 5 -- PM
					AND ul.LicenseeId = @LicenseeId
					
		SELECT	@AMUserId = ui.UserId
		FROM	dbo.UserInfo ui WITH(NOLOCK)
			INNER JOIN dbo.UserLicensee ul WITH(NOLOCK)
				ON	ui.UserId = ul.UserId
					AND ui.PositionId = 6 -- AM
					AND ul.LicenseeId = @LicenseeId
					
		SET @LicAccount = (
								SELECT	la.[Order]		AS '@order'
										,la.AccountType AS '@type'
										,la.UserName	AS '@username'
										,la.UserPwd		AS '@password'
										,la.Url			AS '@url'
								FROM	dbo.LicenseeAccountInfo AS la WITH (NOLOCK)
								WHERE	la.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('root')		
							)
							
		SELECT @AMUserId		AS AMUser
				,@PMUserId		AS PMUser
				,@LicAccount	AS AccountInfo
				,InternalURL
		FROM dbo.Licensee WITH(NOLOCK)
		WHERE LicenseeId = @LicenseeId
	END
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeInfoUpd]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeInfoUpd    Script Date: 9/11/2017 11:37:13 PM ******/
CREATE PROCEDURE [dbo].[OIC_LicenseeInfoUpd]	
	@LicenseeId				INT
	,@UpdateStep1			BIT				= 1
	,@LicenseeTypeId		TINYINT			= NULL
	,@SiteName				NVARCHAR(50)	= NULL
	,@CompanyName			NVARCHAR(50)	= NULL
	,@LicenseeStatusId		TINYINT			= NULL
	,@IsReseller			BIT				= 0
	,@IsChineseMarketOnly	BIT				= 0
	,@SoftLaunch			DATETIME		= NULL
	,@FullLaunch			DATETIME		= NULL
	,@MainUrl				VARCHAR(3000)	= NULL
	,@APIUrl				VARCHAR(3000)	= NULL
	,@LicBackUpLink			XML				= NULL
	,@HasMainContact		BIT				= 0
	,@MainContactName		NVARCHAR(50)	= NULL
	,@Position				NVARCHAR(50)	= NULL
	,@Department			NVARCHAR(50)	= NULL
	,@Email					VARCHAR(50)		= NULL
	,@PhoneNumber			VARCHAR(50)		= NULL
	,@Skype					VARCHAR(50)		= NULL
	,@MainContactRemark		NVARCHAR(300)	= NULL
	,@LocationId			INT				= NULL
	,@CurrenciesOffered		VARCHAR(100)	= NULL
	,@LicTargetMarket		VARCHAR(1000)	= NULL
	,@LicLanguage			XML				= NULL
	,@LicLanguageSB			XML				= NULL
	,@LicService			XML				= NULL
	,@LicRestrictCountry	VARCHAR(1000)	= NULL
	,@RestrictCountryRemark	NVARCHAR(500)	= NULL		
	,@Remark				NVARCHAR(300)	= NULL
	
	,@UpdateStep2			BIT				= 1
	,@LicProduct			XML				= NULL
	,@LicFeature			XML				= NULL
	
	,@UpdateStep3			BIT				= 1
	,@AMUserId				INT				= NULL
	,@PMUserId				INT				= NULL
	,@LicAccount			XML				= NULL
	,@InternalURL			VARCHAR(3000)	= NULL
	
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= ''		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2015-04-05
	Task: Update Licensee [Redmine:#30959]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160511@Percy: Change type of input param @LicFeature [RedmineID: #56935]
		- 20160805@Percy: Expand length of params: @LicTargetMarket, @LicRestrictCountry [RedmineID: #62099]
		- 20160823@Percy: Add param: @LicLanguageSB - Sportbook offered language [RedmineID: #62883]
		- 20170517@Percy: Add Chinese Market Only and Internal Backend URL [RedmineID: #74330]
		- 20170802@Percy: Add Url testing account - add element into @LicAccount [RedmineID: #80712]
		- 20170809@Percy: Extend Url length [RedmineID: #81392]
		- 20170828@Scofield: Add Reseller [#82144]
	
	Param's Explanation:
	* @LicBackupLink
		<root>
			<row val="link1" />
			<row val="link2" />
		</root>
	* @LicService: List of Services
		Format:
				<root>
					<row pid="1" val="kathy.nguyen" />
					<row pid="2" val="password" />
					<row pid="3" val="http:..." />
					<row pid="4" val="http:..." />
				</root>
	* @LicLanguage, @LicLanguageSB
		Format:
				<root>
					<row id="1" />
					<row id="2" />
				</root>
	* @LicProduct, @LicFeature: list of product, feature
				<root>
					<row id="1" launchdate="2014-12-19" terminationdate="2016-05-11"/>
					<row id="3" launchdate="2014-12-19"/>
				</root>
				
	* @LicAccount:
				<root>
					<row order="1" type="1" username="webaccount" password="abc" url="https://" />
					<row order="1" type="2" username="csd" password="1234" url="https://" />
					<row order="1" type="3" username="training" password="12abc" url="https://" />
				</root>
				
	* @CurrenciesOffered, @LicTargetMarket, @LicRestrictCountry
	* @ErrCode:
		= 0: 
		> 0: Specific Error.
  
	* @ErrMsg: Error description.
	
	
	* Log:
	
 */
BEGIN
	SET NOCOUNT ON
	
	-- check licensee name
	EXEC dbo.OIC_LicenseeNameChecking
		@SiteName	= @SiteName
		,@LicenseeId = @LicenseeId
		,@Language	= @Language
		,@ErrCode	= @ErrCode	OUTPUT
		,@ErrMsg	= @ErrMsg	OUTPUT
	
	IF @ErrCode <> 0
	BEGIN
		SELECT @ErrCode, @ErrMsg
		RETURN
	END

	-- For write log
	DECLARE 
		@startRun					DATETIME
		,@endRun					DATETIME
		,@duration					INT
		,@logSPData					NVARCHAR(MAX)
		,@logSPOlddata				NVARCHAR(MAX)
		,@xml						XML
		,@procName					VARCHAR(200)
		-- log step 1
		,@log_backupLink			XML
		,@log_maincontact			XML
		,@log_currency				XML
		,@log_targetedMarket		XML
		,@log_restrictedLocation	XML
		,@log_language				XML
		,@log_languageSB			XML
		,@log_service				XML
		-- log step 2
		,@log_product				XML
		,@log_feature				XML
		-- log step 3
		,@log_account				XML
		,@oldAMUserId				INT
		,@oldPMUserId				INT
		,@AMDisplayName				VARCHAR(50)
		,@PMDisplayName				VARCHAR(50)
		,@location					VARCHAR(50)
	
	SET @startRun = GETDATE()

	-- Get data before update
	IF @UpdateStep1 = 1
	BEGIN
		SET @log_backupLink = (	SELECT	lu.UrlValue AS '@lbul'
								FROM	dbo.UrlBackup AS lu WITH (NOLOCK)
								WHERE	lu.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('bk')		
							)
	
		SET @log_maincontact  = (SELECT	c.ContactID			AS '@cid'
										,c.ContactName		AS '@cn'
										,c.ContactPosition	AS '@cp'
										,c.ContactDepartment AS '@cd'
										,c.ContactEmail		AS '@ce'
										,c.ContactSkype		AS '@cs'
										,c.ContactPhoneNumber	AS '@cpn'
										,c.IsMain			AS '@cim'
										,c.Remark			AS '@crm'
								FROM	dbo.Contact c
								WHERE	licenseeid = @LicenseeId AND c.IsMain = 1
								FOR XML PATH('row'), ROOT('lc')	
							)
		SET @log_currency = (
								SELECT	e.exchangeid AS '@cid'
										,e.Code AS '@cur'
								FROM dbo.LicenseeCurrency AS lc WITH (NOLOCK)
									INNER JOIN bodb02.dbo.Exchange AS e WITH(NOLOCK) 
										ON e.exchangeid = lc.CurrencyId
								WHERE	lc.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('cr')	
							)
		SET @log_targetedMarket = (
								SELECT  lo.LocationId AS '@tmid'
										,lo.LocationName AS '@tmn'
								FROM dbo.LicenseeLocationLimit AS ll WITH (NOLOCK)
									INNER JOIN dbo.Location AS lo WITH(NOLOCK) 
										ON lo.LocationId = ll.LocationLimitId 
										AND ll.LicenseeLocationType = 1
								WHERE	ll.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('tm')	
							)
		SET @log_restrictedLocation = (
								SELECT lo.LocationId AS '@rlid'
										,lo.LocationName AS '@rln'
								FROM dbo.LicenseeLocationLimit AS ll WITH (NOLOCK)
									INNER JOIN dbo.Location AS lo WITH(NOLOCK) 
										ON lo.LocationId = ll.LocationLimitId 
										AND ll.LicenseeLocationType = 2
								WHERE	ll.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('rl')		
							)
						
		SET @log_Language = (
								SELECT	la.LanguageId AS '@llid'
										,la.LanguageName AS '@lln'
								FROM dbo.LicenseeLanguage AS ll WITH (NOLOCK)
									INNER JOIN dbo.Language AS la WITH(NOLOCK) 
										ON la.LanguageId = ll.LanguageId
								WHERE	ll.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('ll')	
							)
						
		SET @log_LanguageSB = (
								SELECT	la.LanguageId AS '@llidsb'
										,la.LanguageName AS '@llnsb'
								FROM dbo.LicenseeProductLanguage AS ll WITH (NOLOCK)
									INNER JOIN dbo.Language AS la WITH(NOLOCK) 
										ON la.LanguageId = ll.LanguageId
								WHERE	ll.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('llsb')	
							)
	
		SET @log_service = (	SELECT	s.ServiceId				AS '@lsid'
										,s.ServiceName				AS '@lsn'
										,lp.PropertyId				as '@lspid'
										,lp.PropertyValue as '@lspv'
								FROM dbo.LicenseeProperty lp
									INNER JOIN dbo.Property p
										ON	p.PropertyId = lp.PropertyId
									INNER JOIN dbo.Service s 
										ON	s.ServiceId = p.ServiceId
								WHERE	licenseeid = @LicenseeId
								FOR XML PATH('row'), ROOT('ls')	
							)
		SELECT @location = LocationName FROM dbo.Location WITH(NOLOCK) WHERE LocationId = (SELECT LicenseeLocationId FROM dbo.Licensee WITH(NOLOCK) WHERE LicenseeId = @LicenseeId)
	END
	
	IF @UpdateStep2 = 1
	BEGIN
		SET @log_product = (
							SELECT	p.ProductId AS '@lpid'
									,p.ProductName AS '@lpn'
									,p.[Order] AS '@lpod'
									,lp.LaunchDate AS '@lpl'
									,lp.TerminationDate AS '@lpt'
							FROM	dbo.LicenseeProduct AS lp WITH (NOLOCK)
								INNER JOIN dbo.Product AS p WITH(NOLOCK) 
									ON	p.ProductId = lp.ProductId
							WHERE	lp.LicenseeId = @LicenseeId
							FOR XML PATH('row'), ROOT('lp')	
						)
		SET @log_feature = (
							SELECT	f.FeatureId AS '@lfid'
									,f.FeatureName AS '@lfn'
									,lf.LaunchDate AS '@lfl'
									,lf.TerminationDate AS '@lft'
							FROM	dbo.LicenseeFeature AS lf WITH (NOLOCK)
								INNER JOIN dbo.Feature AS f WITH(NOLOCK) 
									ON	f.FeatureId = lf.FeatureId
							WHERE	lf.LicenseeId = @LicenseeId
							FOR XML PATH('row'), ROOT('lf')	
						)
	END
	
	IF @UpdateStep3 = 1
	BEGIN
		SELECT @oldPMUserId = ul.UserId, @PMDisplayName = ui.DisplayName
		FROM dbo.UserInfo ui WITH(NOLOCK)
			INNER JOIN dbo.UserLicensee ul WITH(NOLOCK) ON ui.UserId = ul.UserId AND ul.LicenseeId = @licenseeId AND ui.PositionId = 5 -- PM
			
		SELECT @oldAMUserId = ul.UserId, @AMDisplayName = ui.DisplayName
		FROM dbo.UserInfo ui WITH(NOLOCK)
			INNER JOIN dbo.UserLicensee ul WITH(NOLOCK) ON ui.UserId = ul.UserId AND ul.LicenseeId = @licenseeId AND ui.PositionId = 6 -- AM			
	
		SET @log_account = (	SELECT	la.AccountId	AS '@laid'
										,la.UserName	AS '@lan'
										,la.UserPwd		AS '@lap'
										,la.AccountType AS '@lat'
										,la.[Order]		AS '@lod'
										,la.Url			AS '@lu'
								FROM	dbo.LicenseeAccountInfo AS la WITH (NOLOCK)
								WHERE	la.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('la')
						)
	END

	SET @xml = (SELECT	@LicenseeId					AS '@lid'
							,t.LicenseeTypeName			AS '@tn'
							,l.LicenseeName				AS '@ln'
							,l.LicenseeCompanyName		AS '@cn'
							,s.LicenseeStatusName		AS '@sn'
							,l.SoftLaunch				AS '@sl'
							,l.FullLaunch				AS '@fl'
							,l.MainUrl					AS '@mu'
							,l.APILinkageUrl			AS '@au'
							,l.RestrictedLocationRemark	AS '@rlr'			
							,l.Remark					AS '@rm'
							,l.IsChineseMarketOnly		AS '@icm'
							,l.IsReseller				AS '@res'
							,l.InternalURL				AS '@iu'
							,@location					AS '@lc'
							,@AMDisplayName				AS '@amn'
							,@PMDisplayName				AS '@pmn'
							,@log_backupLink
							,@log_maincontact
							,@log_currency
							,@log_Language
							,@log_languageSB
							,@log_restrictedLocation
							,@log_targetedMarket
							,@log_service
							,@log_product
							,@log_feature
							,@log_account
					FROM dbo.Licensee AS l WITH (NOLOCK)
						INNER JOIN dbo.LicenseeStatus AS s WITH(NOLOCK) 
							ON	l.LicenseeStatusId = s.LicenseeStatusId
						INNER JOIN dbo.LicenseeType AS t WITH(NOLOCK) 
							ON	l.LicenseeTypeId = t.LicenseeTypeId
					WHERE	l.LicenseeId = @LicenseeId
					FOR XML PATH('r'), TYPE
				)
	
	SELECT @logSPOldData = CONVERT(NVARCHAR(MAX), @xml)
		
	-- Step1: Update general info
	IF @UpdateStep1 = 1
	BEGIN
				EXEC dbo.OIC_LicenseeInfoUpd_Step1
			@LicenseeId					= @LicenseeId
			,@LicenseeTypeId			= @LicenseeTypeId
			,@SiteName					= @SiteName
			,@CompanyName				= @CompanyName
			,@LicenseeStatusId			= @LicenseeStatusId
			,@IsReseller				= @IsReseller
			,@IsChineseMarketOnly		= @IsChineseMarketOnly
			,@SoftLaunch				= @SoftLaunch
			,@FullLaunch				= @FullLaunch
			,@MainUrl					= @MainUrl
			,@APIUrl					= @APIUrl
			,@LicBackUpLink				= @LicBackUpLink
			,@HasMainContact			= @HasMainContact
			,@MainContactName			= @MainContactName
			,@Position					= @Position
			,@Department				= @Department
			,@Email						= @Email
			,@PhoneNumber				= @PhoneNumber
			,@Skype						= @Skype
			,@MainContactRemark			= @MainContactRemark
			,@LocationId				= @LocationId
			,@CurrenciesOffered			= @CurrenciesOffered
			,@LicTargetMarket			= @LicTargetMarket
			,@LicLanguage				= @LicLanguage
			,@LicLanguageSB				= @LicLanguageSB
			,@LicService				= @LicService
			,@LicRestrictCountry		= @LicRestrictCountry
			,@RestrictCountryRemark		= @RestrictCountryRemark		
			,@Remark					= @Remark
			
			,@UserId					= @UserId
			,@Language					= @Language
			,@IP						= @IP
			,@ErrCode					= @ErrCode		OUTPUT
			,@ErrMsg					= @ErrMsg		OUTPUT		
		
		IF @ErrCode <> 0
		BEGIN
			SELECT	@ErrCode = @ErrCode
					,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](6, @Language) -- Edit client failed at step 1
		END
		ELSE
		BEGIN
			-- get data after Step 1
			SET @log_backupLink = (	SELECT	lu.UrlValue AS '@lbul'
									FROM	dbo.UrlBackup AS lu WITH (NOLOCK)
									WHERE	lu.LicenseeId = @LicenseeId
									FOR XML PATH('row'), ROOT('bk')		
								)
	
			SET @log_maincontact  = (SELECT	c.ContactID			AS '@cid'
											,c.ContactName		AS '@cn'
											,c.ContactPosition	AS '@cp'
											,c.ContactDepartment AS '@cd'
											,c.ContactEmail		AS '@ce'
											,c.ContactSkype		AS '@cs'
											,c.ContactPhoneNumber	AS '@cpn'
											,c.IsMain			AS '@cim'
											,c.Remark			AS '@crm'
									FROM	dbo.Contact c
									WHERE	licenseeid = @LicenseeId AND c.IsMain = 1
									FOR XML PATH('row'), ROOT('lc')	
								)
			SET @log_currency = (
									SELECT	e.exchangeid AS '@cid'
											,e.Code AS '@cur'
									FROM dbo.LicenseeCurrency AS lc WITH (NOLOCK)
										INNER JOIN bodb02.dbo.Exchange AS e WITH(NOLOCK) 
											ON e.exchangeid = lc.CurrencyId
									WHERE	lc.LicenseeId = @LicenseeId
									FOR XML PATH('row'), ROOT('cr')	
								)
			SET @log_targetedMarket = (
									SELECT  lo.LocationId AS '@tmid'
											,lo.LocationName AS '@tmn'
									FROM dbo.LicenseeLocationLimit AS ll WITH (NOLOCK)
										INNER JOIN dbo.Location AS lo WITH(NOLOCK) 
											ON lo.LocationId = ll.LocationLimitId 
											AND ll.LicenseeLocationType = 1
									WHERE	ll.LicenseeId = @LicenseeId
									FOR XML PATH('row'), ROOT('tm')	
								)
			SET @log_restrictedLocation = (
									SELECT lo.LocationId AS '@rlid'
											,lo.LocationName AS '@rln'
									FROM dbo.LicenseeLocationLimit AS ll WITH (NOLOCK)
										INNER JOIN dbo.Location AS lo WITH(NOLOCK) 
											ON lo.LocationId = ll.LocationLimitId 
											AND ll.LicenseeLocationType = 2
									WHERE	ll.LicenseeId = @LicenseeId
									FOR XML PATH('row'), ROOT('rl')		
								)
						
			SET @log_Language = (
									SELECT	la.LanguageId AS '@llid'
											,la.LanguageName AS '@lln'
									FROM dbo.LicenseeLanguage AS ll WITH (NOLOCK)
										INNER JOIN dbo.Language AS la WITH(NOLOCK) 
											ON la.LanguageId = ll.LanguageId
									WHERE	ll.LicenseeId = @LicenseeId
									FOR XML PATH('row'), ROOT('ll')	
								)
						
			SET @log_LanguageSB = (
									SELECT	la.LanguageId AS '@llidsb'
											,la.LanguageName AS '@llnsb'
									FROM dbo.LicenseeProductLanguage AS ll WITH (NOLOCK)
										INNER JOIN dbo.Language AS la WITH(NOLOCK) 
											ON la.LanguageId = ll.LanguageId
									WHERE	ll.LicenseeId = @LicenseeId
									FOR XML PATH('row'), ROOT('llsb')	
								)
	
			SET @log_service = (	SELECT	s.ServiceId				AS '@lsid'
											,s.ServiceName				AS '@lsn'
											,lp.PropertyId				as '@lspid'
											,lp.PropertyValue as '@lspv'
									FROM dbo.LicenseeProperty lp
										INNER JOIN dbo.Property p
											ON	p.PropertyId = lp.PropertyId
										INNER JOIN dbo.Service s 
											ON	s.ServiceId = p.ServiceId
									WHERE	licenseeid = @LicenseeId
									FOR XML PATH('row'), ROOT('ls')	
								)
			SELECT @location = LocationName FROM dbo.Location WITH(NOLOCK) WHERE LocationId = @LocationId
		END
	END
	-- END Step1

	-- Step2: Update product & feature 
	IF @UpdateStep2 = 1
	BEGIN
		EXEC dbo.OIC_LicenseeInfoUpd_Step2
			@LicenseeId		= @LicenseeId
			,@LicProduct	= @LicProduct
			,@LicFeature	= @LicFeature
		
			,@UserId		= @UserId
			,@Language		= @Language
			,@IP			= @IP
			,@ErrCode		= @ErrCode	OUTPUT
			,@ErrMsg		= @ErrMsg	OUTPUT
		
		IF @ErrCode <> 0
		BEGIN
			SELECT	@ErrCode = @ErrCode
					,@ErrMsg =  @ErrMsg + [dbo].[f_Get_MsgNamebyMsgID](7, @Language) -- Edit client failed at step 2
		END
		ELSE
		BEGIN
			-- get data after Step 2
			SET @log_product = (
								SELECT	p.ProductId AS '@lpid'
										,p.ProductName AS '@lpn'
										,p.[Order] AS '@lpod'
										,lp.LaunchDate AS '@lpl'
										,lp.TerminationDate AS '@lpt'
								FROM	dbo.LicenseeProduct AS lp WITH (NOLOCK)
									INNER JOIN dbo.Product AS p WITH(NOLOCK) 
										ON	p.ProductId = lp.ProductId
								WHERE	lp.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('lp')	
							)
			SET @log_feature = (
								SELECT	f.FeatureId AS '@lfid'
										,f.FeatureName AS '@lfn'
										,lf.LaunchDate AS '@lfl'
										,lf.TerminationDate AS '@lft'
								FROM	dbo.LicenseeFeature AS lf WITH (NOLOCK)
									INNER JOIN dbo.Feature AS f WITH(NOLOCK) 
										ON	f.FeatureId = lf.FeatureId
								WHERE	lf.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('lf')	
							)
		END
	END	
	-- END Step2
	
	-- Step3: Internal Person in Charge 
	IF @UpdateStep3 = 1
	BEGIN
		EXEC dbo.OIC_LicenseeInfoUpd_Step3
			@LicenseeId			= @LicenseeId
			,@AMUserId			= @AMUserId
			,@PMUserId			= @PMUserId
			,@oldAMUserId		= @oldAMUserId
			,@oldPMUserId		= @oldPMUserId
			,@AMDisplayName		= @AMDisplayName
			,@PMDisplayName		= @PMDisplayName
			,@LicAccount		= @LicAccount
			,@InternalURL		= @InternalURL
			
			,@UserId			= @UserId
			,@Language			= @Language
			,@IP				= @IP
			,@ErrCode			= @ErrCode	OUTPUT
			,@ErrMsg			= @ErrMsg	OUTPUT
			
		IF @ErrCode <> 0
		BEGIN
			SELECT	@ErrCode = @ErrCode
					,@ErrMsg = @ErrMsg + [dbo].[f_Get_MsgNamebyMsgID](8, @Language) -- Edit client failed at step 3
		END
		ELSE
		BEGIN
			-- get data after Step 3
			SELECT @PMDisplayName = ui.DisplayName
			FROM	dbo.UserInfo ui WITH(NOLOCK)
			WHERE	ui.UserId = @PMUserId
						AND ui.PositionId = 5 -- PM
			
			SELECT @AMDisplayName = ui.DisplayName
			FROM	dbo.UserInfo ui WITH(NOLOCK)
			WHERE	ui.UserId = @AMUserId
						AND ui.PositionId = 6 -- AM
				
			SET @log_account = (
								SELECT	la.AccountId	AS '@laid'
										,la.UserName	AS '@lan'
										,la.UserPwd		AS '@lap'
										,la.AccountType AS '@lat'
										,la.[Order]		AS '@lod'
										,la.Url			AS '@lu'
								FROM dbo.LicenseeAccountInfo AS la WITH (NOLOCK)
								WHERE	la.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('la')	
							)
		END
	END
	--END Step3

	-- Write log
	SET @xml = (		SELECT	@LicenseeId					AS '@lid'
								,t.LicenseeTypeName			AS '@tn'
								,l.LicenseeName				AS '@ln'
								,l.LicenseeCompanyName		AS '@cn'
								,s.LicenseeStatusName		AS '@sn'
								,l.SoftLaunch				AS '@sl'
								,l.FullLaunch				AS '@fl'
								,l.MainUrl					AS '@mu'
								,l.APILinkageUrl			AS '@au'
								,l.RestrictedLocationRemark	AS '@rlr'			
								,l.Remark					AS '@rm'
								,l.IsChineseMarketOnly		AS '@icm'
								,l.IsReseller				AS '@res'
								,l.InternalURL				AS '@iu'
								,@location					AS '@lc'
								,@AMDisplayName				AS '@amn'
								,@PMDisplayName				AS '@pmn'
								,@log_backupLink
								,@log_maincontact
								,@log_currency
								,@log_Language
								,@log_LanguageSB
								,@log_restrictedLocation
								,@log_targetedMarket
								,@log_service
								,@log_product
								,@log_feature
								,@log_account
						FROM dbo.Licensee AS l WITH (NOLOCK)
							INNER JOIN dbo.LicenseeStatus AS s WITH(NOLOCK) 
								ON	l.LicenseeStatusId = s.LicenseeStatusId
							INNER JOIN dbo.LicenseeType AS t WITH(NOLOCK) 
								ON	l.LicenseeTypeId = t.LicenseeTypeId
						WHERE	l.LicenseeId = @LicenseeId
						FOR XML PATH('r'), TYPE
				)
	
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOlddata
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeInfoUpd_Step1]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeInfoUpd_Step1    Script Date: 9/11/2017 11:37:15 PM ******/
CREATE PROCEDURE [dbo].[OIC_LicenseeInfoUpd_Step1]
	@LicenseeTypeId			TINYINT
	,@SiteName				NVARCHAR(50)
	,@CompanyName			NVARCHAR(50)	= NULL
	,@LicenseeStatusId		TINYINT
	,@IsReseller				BIT				= 0
	,@IsChineseMarketOnly	BIT				= 0
	,@SoftLaunch			DATETIME		= NULL
	,@FullLaunch			DATETIME		= NULL
	,@MainUrl				VARCHAR(3000)	= NULL
	,@APIUrl				VARCHAR(3000)	= NULL
	,@LicBackUpLink			XML				= NULL
	,@HasMainContact		BIT				= 0 -- has main contact info
	,@MainContactName		NVARCHAR(50)	= NULL
	,@Position				NVARCHAR(50)	= NULL
	,@Department			NVARCHAR(50)	= NULL
	,@Email					VARCHAR(50)		= NULL
	,@PhoneNumber			VARCHAR(50)		= NULL
	,@Skype					VARCHAR(50)		= NULL
	,@MainContactRemark		NVARCHAR(300)	= NULL
	,@LocationId			INT				= NULL
	,@CurrenciesOffered		VARCHAR(100)	= NULL
	,@LicTargetMarket		VARCHAR(1000)	= NULL
	,@LicLanguage			XML				= NULL
	,@LicLanguageSB			XML				= NULL
	,@LicService			XML				= NULL
	,@LicRestrictCountry	VARCHAR(1000)	= NULL
	,@RestrictCountryRemark	NVARCHAR(500)	= NULL		
	,@Remark				NVARCHAR(300)	= NULL
	
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
	
	,@LicenseeId			INT				= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2014-12-18
	Task: Update client general info - Step1 [Redmine:#30959]
	DB: DBOIC.BODB_OIC 
	
	Revisions:
		- 20160805@Percy: Expand length of params: @LicTargetMarket, @LicRestrictCountry [RedmineID: #62099]
		- 20160823@Percy: Add param: @LicLanguageSB - Sportbook offered language [RedmineID: #62883]
		- 20170517@Percy: Add Chinese Market Only [RedmineID: #74330]
		- 20170809@Percy: Extend Url length [RedmineID: #81392]
		- 20170828@Scofield: Add Reseller [#82144]
	
	Param's Explanation:
	* @LicBackupLink
		<root>
			<row val="link1" />
			<row val="link2" />
		</root>
	* @LicService: List of Services
		Format:
				<root>
					<row pid="1" val="kathy.nguyen" />
					<row pid="2" val="password" />
					<row pid="3" val="http:..." />
					<row pid="4" val="http:..." />
				</root>
	* @LicLanguage, @LicLanguageSB
		Format:
				<root>
					<row id="1" />
					<row id="2" />
				</root>
	* @CurrenciesOffered, @LicTargetMarket, @LicRestrictCountry: 1,2,3
	
	* @ErrCode:
		= 0: 
		> 0: Specific Error.
  
	* @ErrMsg: Error description.
 */
BEGIN
	SET NOCOUNT ON

	-- check licensee name
	EXEC dbo.OIC_LicenseeNameChecking
		@SiteName	= @SiteName
		,@LicenseeId = @LicenseeId
		,@Language	= @Language
		,@ErrCode	= @ErrCode	OUTPUT
		,@ErrMsg	= @ErrMsg	OUTPUT
	
	IF @ErrCode <> 0
	BEGIN
		SELECT @ErrCode = 100
		RETURN
	END
	
	DECLARE @tblUrlBackup			TABLE (urlValue VARCHAR(3000), [Order] TINYINT)
	DECLARE @tblLanguage			TABLE (LanguageId TINYINT)
	DECLARE @tblLanguageSB			TABLE (LanguageId TINYINT)
	DECLARE @tblService				TABLE (ServiceId TINYINT, PropertyId TINYINT, PropertyValue VARCHAR(3000))
	
	DECLARE @MainContactId			INT
	
	-- Update Licensee info
	BEGIN TRY
		UPDATE	dbo.Licensee WITH(ROWLOCK, UPDLOCK)
			SET	LicenseeName				= @SiteName
				,LicenseeCompanyName		= @CompanyName
				,LicenseeStatusId			= @LicenseeStatusId
				,SoftLaunch					= @SoftLaunch
				,FullLaunch					= @FullLaunch
				,MainUrl					= @MainUrl
				,APILinkageUrl				= @APIUrl
				,LicenseeLocationId			= @LocationId
				,RestrictedLocationRemark	= @RestrictCountryRemark
				,Remark						= @Remark
				,LicenseeTypeId				= @LicenseeTypeId
				,IsChineseMarketOnly		= @IsChineseMarketOnly
				,IsReseller					= @IsReseller
		WHERE	LicenseeId					= @LicenseeId
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 101
		RETURN
	END CATCH	
	
	-- Update url backup
	IF @LicBackUpLink IS NOT NULL
	BEGIN TRY
		INSERT INTO @tblUrlBackup(urlValue, [Order])
		SELECT	t.c.value('@val', 'varchar(3000)')
				,ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS rownumber
		FROM	@LicBackUpLink.nodes('root/row') t(c)
		
		MERGE	dbo.UrlBackup u
		USING	(SELECT urlValue, [Order] FROM @tblUrlBackup) t
			ON	u.[Order] = t.[Order] 
				AND u.LicenseeId = @LicenseeId
		WHEN MATCHED AND u.UrlValue <> t.urlValue THEN UPDATE SET u.UrlValue = t.urlValue
		WHEN NOT MATCHED BY TARGET THEN INSERT(LicenseeId, UrlValue, [Order]) VALUES(@LicenseeId, t.urlValue, t.[Order])
		WHEN NOT MATCHED BY SOURCE AND LicenseeId = @LicenseeId THEN DELETE;
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 102
		RETURN
	END CATCH	
		
	-- Update main contact
	IF @HasMainContact = 1
	BEGIN TRY
		SELECT	@MainContactId = ContactID
		FROM	dbo.Contact WITH(NOLOCK)
		WHERE	LicenseeID = @LicenseeId
				AND IsMain = 1
		
		IF @@ROWCOUNT = 0 
			INSERT INTO dbo.Contact(
					LicenseeID
					,ContactName
					,ContactPosition
					,ContactDepartment
					,ContactEmail
					,ContactSkype
					,ContactPhoneNumber
					,ContactType
					,Remark
					,IsMain
				)
			SELECT	@LicenseeId
					,@MainContactName
					,@Position
					,@Department
					,@Email
					,@Skype
					,@PhoneNumber
					,0 -- individual
					,@MainContactRemark
					,1
		ELSE
			UPDATE	dbo.Contact
				SET	ContactName			= @MainContactName
					,ContactPosition	= @Position
					,ContactDepartment	= @Department
					,ContactEmail		= @Email
					,ContactSkype		= @Skype
					,ContactPhoneNumber = @PhoneNumber
					,Remark				= @MainContactRemark
			WHERE	ContactID = @MainContactId
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 103
		RETURN
	END CATCH	
			
	-- Update offered currencies
	IF @CurrenciesOffered IS NOT NULL
	BEGIN TRY
		MERGE	dbo.LicenseeCurrency lc
		USING	(SELECT	CONVERT(INT, val) AS CurrencyId FROM dbo.strSplit(@CurrenciesOffered, ',')) t
			ON	lc.CurrencyId = t.CurrencyId 
				AND lc.LicenseeId = @LicenseeId
		WHEN NOT MATCHED BY TARGET THEN INSERT(Licenseeid, CurrencyId) VALUES (@LicenseeId, t.CurrencyId)
		WHEN NOT MATCHED BY SOURCE AND lc.LicenseeId = @LicenseeId THEN DELETE;
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 104
		RETURN
	END CATCH	
		
	-- Update targeted market
	IF @LicTargetMarket IS NOT NULL
	BEGIN TRY
		MERGE	dbo.LicenseeLocationLimit l
		USING	(SELECT	CONVERT(INT, val) AS LocationId FROM dbo.strSplit(@LicTargetMarket, ',')) t
			ON	l.LocationLimitId = t.LocationId 
				AND l.LicenseeId = @LicenseeId 
				AND l.LicenseeLocationType = 1
		WHEN NOT MATCHED BY TARGET THEN INSERT (LicenseeId, LicenseeLocationType, LocationLimitId) VALUES (@LicenseeId, 1, t.LocationId)
		WHEN NOT MATCHED BY SOURCE AND l.LicenseeId = @LicenseeId AND l.LicenseeLocationType = 1 THEN DELETE;			
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 105
		RETURN
	END CATCH	
		
	-- Update prefered comunicate language
	IF @LicLanguage IS NOT NULL
	BEGIN TRY
		INSERT INTO @tblLanguage(LanguageId)
		SELECT	t.c.value('@id','int')
		FROM @LicLanguage.nodes('root/row') t(c)
	
		MERGE	dbo.LicenseeLanguage l
		USING	(SELECT * FROM @tblLanguage) t
			ON	l.LanguageId = t.LanguageId 
				AND l.LicenseeId = @LicenseeId
		WHEN NOT MATCHED BY TARGET THEN INSERT (LicenseeId, LanguageId) VALUES (@LicenseeId, t.LanguageId)
		WHEN NOT MATCHED BY SOURCE AND l.LicenseeId = @LicenseeId THEN DELETE;
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 106 
		RETURN
	END CATCH	
		
	-- Update service included
	IF @LicService IS NOT NULL
	BEGIN TRY
		INSERT INTO @tblService (PropertyId, PropertyValue)
		SELECT	t.c.value('@pid', 'tinyint') AS Propertyid
  				,t.c.value('@val', 'varchar(3000)') AS Value
		FROM @LicService.nodes('/root/row') AS t(c)	
		
		MERGE	dbo.LicenseeProperty l
		USING	(SELECT * FROM @tblService) t
			ON	l.PropertyId = t.PropertyId 
				AND l.LicenseeId = @LicenseeId
		WHEN MATCHED AND l.PropertyValue <> t.PropertyValue THEN UPDATE SET l.PropertyValue = t.PropertyValue
		WHEN NOT MATCHED BY TARGET THEN INSERT (LicenseeId, PropertyId, PropertyValue) VALUES (@LicenseeId, t.PropertyId, t.PropertyValue)
		WHEN NOT MATCHED BY SOURCE AND l.LicenseeId = @LicenseeId THEN DELETE;
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 107
		RETURN
	END CATCH	
	
	-- Update Restrict country	
	IF @LicRestrictCountry IS NOT NULL
	BEGIN TRY
		MERGE	dbo.LicenseeLocationLimit l
		USING	(SELECT CONVERT(INT, val) AS LocationId FROM dbo.strSplit(@LicRestrictCountry,',')) t
			ON	l.LocationLimitId = t.LocationId
				AND l.LicenseeId = @LicenseeId
				AND l.LicenseeLocationType = 2
		WHEN NOT MATCHED BY TARGET THEN INSERT (LicenseeId, LicenseeLocationType, LocationLimitId) VALUES (@LicenseeId, 2, t.Locationid)
		WHEN NOT MATCHED BY SOURCE AND l.LicenseeId = @LicenseeId AND l.LicenseeLocationType = 2 THEN DELETE;		
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 108
		RETURN
	END CATCH

	-- Update Sportbook offered language
	IF @LicLanguageSB IS NOT NULL
	BEGIN TRY
		INSERT INTO @tblLanguageSB(LanguageId)
		SELECT	t.c.value('@id','int')
		FROM @LicLanguageSB.nodes('root/row') t(c)
	
		MERGE	dbo.LicenseeProductLanguage l
		USING	(SELECT * FROM @tblLanguageSB) t
			ON	l.LanguageId = t.LanguageId 
				AND l.LicenseeId = @LicenseeId
		WHEN NOT MATCHED BY TARGET THEN INSERT (LicenseeId, LanguageId) VALUES (@LicenseeId, t.LanguageId)
		WHEN NOT MATCHED BY SOURCE AND l.LicenseeId = @LicenseeId THEN DELETE;
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 109
		RETURN
	END CATCH
	
	SELECT @ErrCode = 0
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeInfoUpd_Step1_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OIC_LicenseeInfoUpd_Step1_xtest]
	@LicenseeTypeId			TINYINT
	,@SiteName				NVARCHAR(50)
	,@CompanyName			NVARCHAR(50)	= NULL
	,@LicenseeStatusId		TINYINT
	,@IsReseller				BIT				= 0
	,@IsChineseMarketOnly	BIT				= 0
	,@SoftLaunch			DATETIME		= NULL
	,@FullLaunch			DATETIME		= NULL
	,@MainUrl				VARCHAR(3000)	= NULL
	,@APIUrl				VARCHAR(3000)	= NULL
	,@LicBackUpLink			XML				= NULL
	,@HasMainContact		BIT				= 0 -- has main contact info
	,@MainContactName		NVARCHAR(50)	= NULL
	,@Position				NVARCHAR(50)	= NULL
	,@Department			NVARCHAR(50)	= NULL
	,@Email					VARCHAR(50)		= NULL
	,@PhoneNumber			VARCHAR(50)		= NULL
	,@Skype					VARCHAR(50)		= NULL
	,@MainContactRemark		NVARCHAR(300)	= NULL
	,@LocationId			INT				= NULL
	,@CurrenciesOffered		VARCHAR(100)	= NULL
	,@LicTargetMarket		VARCHAR(1000)	= NULL
	,@LicLanguage			XML				= NULL
	,@LicLanguageSB			XML				= NULL
	,@LicService			XML				= NULL
	,@LicRestrictCountry	VARCHAR(1000)	= NULL
	,@RestrictCountryRemark	NVARCHAR(500)	= NULL		
	,@Remark				NVARCHAR(300)	= NULL
	
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
	
	,@LicenseeId			INT				= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2014-12-18
	Task: Update client general info - Step1 [Redmine:#30959]
	DB: DBOIC.BODB_OIC 
	
	Revisions:
		- 20160805@Percy: Expand length of params: @LicTargetMarket, @LicRestrictCountry [RedmineID: #62099]
		- 20160823@Percy: Add param: @LicLanguageSB - Sportbook offered language [RedmineID: #62883]
		- 20170517@Percy: Add Chinese Market Only [RedmineID: #74330]
		- 20170809@Percy: Extend Url length [RedmineID: #81392]
		- 20170828@Scofield: Add Reseller [#82144]
	
	Param's Explanation:
	* @LicBackupLink
		<root>
			<row val="link1" />
			<row val="link2" />
		</root>
	* @LicService: List of Services
		Format:
				<root>
					<row pid="1" val="kathy.nguyen" />
					<row pid="2" val="password" />
					<row pid="3" val="http:..." />
					<row pid="4" val="http:..." />
				</root>
	* @LicLanguage, @LicLanguageSB
		Format:
				<root>
					<row id="1" />
					<row id="2" />
				</root>
	* @CurrenciesOffered, @LicTargetMarket, @LicRestrictCountry: 1,2,3
	
	* @ErrCode:
		= 0: 
		> 0: Specific Error.
  
	* @ErrMsg: Error description.
 */
BEGIN
	SET NOCOUNT ON

	-- check licensee name
	EXEC dbo.OIC_LicenseeNameChecking
		@SiteName	= @SiteName
		,@LicenseeId = @LicenseeId
		,@Language	= @Language
		,@ErrCode	= @ErrCode	OUTPUT
		,@ErrMsg	= @ErrMsg	OUTPUT
	
	IF @ErrCode <> 0
	BEGIN
		SELECT @ErrCode = 100
		RETURN
	END
	
	DECLARE @tblUrlBackup			TABLE (urlValue VARCHAR(3000), [Order] TINYINT)
	DECLARE @tblLanguage			TABLE (LanguageId TINYINT)
	DECLARE @tblLanguageSB			TABLE (LanguageId TINYINT)
	DECLARE @tblService				TABLE (ServiceId TINYINT, PropertyId TINYINT, PropertyValue VARCHAR(3000))
	
	DECLARE @MainContactId			INT
	
	-- Update Licensee info
	BEGIN TRY
		UPDATE	dbo.Licensee WITH(ROWLOCK, UPDLOCK)
			SET	LicenseeName				= @SiteName
				,LicenseeCompanyName		= @CompanyName
				,LicenseeStatusId			= @LicenseeStatusId
				,SoftLaunch					= @SoftLaunch
				,FullLaunch					= @FullLaunch
				,MainUrl					= @MainUrl
				,APILinkageUrl				= @APIUrl
				,LicenseeLocationId			= @LocationId
				,RestrictedLocationRemark	= @RestrictCountryRemark
				,Remark						= @Remark
				,LicenseeTypeId				= @LicenseeTypeId
				,IsChineseMarketOnly		= @IsChineseMarketOnly
				,IsReseller					= @IsReseller
		WHERE	LicenseeId					= @LicenseeId
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 101
		RETURN
	END CATCH	
	
	-- Update url backup
	IF @LicBackUpLink IS NOT NULL
	BEGIN TRY
		INSERT INTO @tblUrlBackup(urlValue, [Order])
		SELECT	t.c.value('@val', 'varchar(3000)')
				,ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS rownumber
		FROM	@LicBackUpLink.nodes('root/row') t(c)
		
		MERGE	dbo.UrlBackup u
		USING	(SELECT urlValue, [Order] FROM @tblUrlBackup) t
			ON	u.[Order] = t.[Order] 
				AND u.LicenseeId = @LicenseeId
		WHEN MATCHED AND u.UrlValue <> t.urlValue THEN UPDATE SET u.UrlValue = t.urlValue
		WHEN NOT MATCHED BY TARGET THEN INSERT(LicenseeId, UrlValue, [Order]) VALUES(@LicenseeId, t.urlValue, t.[Order])
		WHEN NOT MATCHED BY SOURCE AND LicenseeId = @LicenseeId THEN DELETE;
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 102
		RETURN
	END CATCH	
		
	-- Update main contact
	IF @HasMainContact = 1
	BEGIN TRY
		SELECT	@MainContactId = ContactID
		FROM	dbo.Contact WITH(NOLOCK)
		WHERE	LicenseeID = @LicenseeId
				AND IsMain = 1
		
		IF @@ROWCOUNT = 0 
			INSERT INTO dbo.Contact(
					LicenseeID
					,ContactName
					,ContactPosition
					,ContactDepartment
					,ContactEmail
					,ContactSkype
					,ContactPhoneNumber
					,ContactType
					,Remark
					,IsMain
				)
			SELECT	@LicenseeId
					,@MainContactName
					,@Position
					,@Department
					,@Email
					,@Skype
					,@PhoneNumber
					,0 -- individual
					,@MainContactRemark
					,1
		ELSE
			UPDATE	dbo.Contact
				SET	ContactName			= @MainContactName
					,ContactPosition	= @Position
					,ContactDepartment	= @Department
					,ContactEmail		= @Email
					,ContactSkype		= @Skype
					,ContactPhoneNumber = @PhoneNumber
					,Remark				= @MainContactRemark
			WHERE	ContactID = @MainContactId
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 103
		RETURN
	END CATCH	
			
	-- Update offered currencies
	IF @CurrenciesOffered IS NOT NULL
	BEGIN TRY
		MERGE	dbo.LicenseeCurrency lc
		USING	(SELECT	CONVERT(INT, val) AS CurrencyId FROM dbo.strSplit(@CurrenciesOffered, ',')) t
			ON	lc.CurrencyId = t.CurrencyId 
				AND lc.LicenseeId = @LicenseeId
		WHEN NOT MATCHED BY TARGET THEN INSERT(Licenseeid, CurrencyId) VALUES (@LicenseeId, t.CurrencyId)
		WHEN NOT MATCHED BY SOURCE AND lc.LicenseeId = @LicenseeId THEN DELETE;
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 104
		RETURN
	END CATCH	
		
	-- Update targeted market
	IF @LicTargetMarket IS NOT NULL
	BEGIN TRY
		MERGE	dbo.LicenseeLocationLimit l
		USING	(SELECT	CONVERT(INT, val) AS LocationId FROM dbo.strSplit(@LicTargetMarket, ',')) t
			ON	l.LocationLimitId = t.LocationId 
				AND l.LicenseeId = @LicenseeId 
				AND l.LicenseeLocationType = 1
		WHEN NOT MATCHED BY TARGET THEN INSERT (LicenseeId, LicenseeLocationType, LocationLimitId) VALUES (@LicenseeId, 1, t.LocationId)
		WHEN NOT MATCHED BY SOURCE AND l.LicenseeId = @LicenseeId AND l.LicenseeLocationType = 1 THEN DELETE;			
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 105
		RETURN
	END CATCH	
		
	-- Update prefered comunicate language
	IF @LicLanguage IS NOT NULL
	BEGIN TRY
		INSERT INTO @tblLanguage(LanguageId)
		SELECT	t.c.value('@id','int')
		FROM @LicLanguage.nodes('root/row') t(c)
	
		MERGE	dbo.LicenseeLanguage l
		USING	(SELECT * FROM @tblLanguage) t
			ON	l.LanguageId = t.LanguageId 
				AND l.LicenseeId = @LicenseeId
		WHEN NOT MATCHED BY TARGET THEN INSERT (LicenseeId, LanguageId) VALUES (@LicenseeId, t.LanguageId)
		WHEN NOT MATCHED BY SOURCE AND l.LicenseeId = @LicenseeId THEN DELETE;
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 106 
		RETURN
	END CATCH	
		
	-- Update service included
	IF @LicService IS NOT NULL
	BEGIN TRY
		INSERT INTO @tblService (PropertyId, PropertyValue)
		SELECT	t.c.value('@pid', 'tinyint') AS Propertyid
  				,t.c.value('@val', 'varchar(3000)') AS Value
		FROM @LicService.nodes('/root/row') AS t(c)	
		
		MERGE	dbo.LicenseeProperty l
		USING	(SELECT * FROM @tblService) t
			ON	l.PropertyId = t.PropertyId 
				AND l.LicenseeId = @LicenseeId
		WHEN MATCHED AND l.PropertyValue <> t.PropertyValue THEN UPDATE SET l.PropertyValue = t.PropertyValue
		WHEN NOT MATCHED BY TARGET THEN INSERT (LicenseeId, PropertyId, PropertyValue) VALUES (@LicenseeId, t.PropertyId, t.PropertyValue)
		WHEN NOT MATCHED BY SOURCE AND l.LicenseeId = @LicenseeId THEN DELETE;
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 107
		RETURN
	END CATCH	
	
	-- Update Restrict country	
	IF @LicRestrictCountry IS NOT NULL
	BEGIN TRY
		MERGE	dbo.LicenseeLocationLimit l
		USING	(SELECT CONVERT(INT, val) AS LocationId FROM dbo.strSplit(@LicRestrictCountry,',')) t
			ON	l.LocationLimitId = t.LocationId
				AND l.LicenseeId = @LicenseeId
				AND l.LicenseeLocationType = 2
		WHEN NOT MATCHED BY TARGET THEN INSERT (LicenseeId, LicenseeLocationType, LocationLimitId) VALUES (@LicenseeId, 2, t.Locationid)
		WHEN NOT MATCHED BY SOURCE AND l.LicenseeId = @LicenseeId AND l.LicenseeLocationType = 2 THEN DELETE;		
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 108
		RETURN
	END CATCH

	-- Update Sportbook offered language
	IF @LicLanguageSB IS NOT NULL
	BEGIN TRY
		INSERT INTO @tblLanguageSB(LanguageId)
		SELECT	t.c.value('@id','int')
		FROM @LicLanguageSB.nodes('root/row') t(c)
	
		MERGE	dbo.LicenseeProductLanguage l
		USING	(SELECT * FROM @tblLanguageSB) t
			ON	l.LanguageId = t.LanguageId 
				AND l.LicenseeId = @LicenseeId
		WHEN NOT MATCHED BY TARGET THEN INSERT (LicenseeId, LanguageId) VALUES (@LicenseeId, t.LanguageId)
		WHEN NOT MATCHED BY SOURCE AND l.LicenseeId = @LicenseeId THEN DELETE;
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 109
		RETURN
	END CATCH
	
	SELECT @ErrCode = 0
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeInfoUpd_Step2]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeInfoUpd_Step2    Script Date: 11/21/2016 10:54:05 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeInfoUpd_Step2    Script Date: 11/11/2016 10:29:58 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeInfoUpd_Step2]
	@LicenseeId				INT
	,@LicProduct			XML				= NULL
	,@LicFeature			XML				= NULL
	
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150505
	Task: Update product & feature - Step2  [Redmine:#30959]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160511@Percy: Change type of input param @LicFeature [RedmineID: #56935]
	
	Param's Explanation:
	- @LicProduct, @LicFeature: list of product, feature
				<root>
					<row id="1" launchdate="2014-12-19" terminationdate="2016-05-11"/>
					<row id="3" launchdate="2014-12-19"/>
				</root>
	
	- @ErrCode:
		= 0: 
		> 0: Specific Error.
  
	- @ErrMsg: Error description.
	
	
 */
BEGIN
	SET NOCOUNT ON

	DECLARE @tblProduct TABLE (ProductId TINYINT, LaunchDate DATETIME, TerminationDate DATETIME)
	DECLARE @tblFeature TABLE (FeatureId TINYINT, LaunchDate DATETIME, TerminationDate DATETIME)
	
	-- Insert product
	IF @LicProduct IS NOT NULL
	BEGIN TRY
		INSERT INTO @tblProduct(
				ProductId
				,LaunchDate
				,TerminationDate
		)
		SELECT	t.c.value('@id','int')
				,t.c.value('@launchdate', 'datetime') AS LaunchDate
				,t.c.value('@terminationdate', 'datetime') AS TerminationDate
		FROM	@LicProduct.nodes('root/row') t(c)
		
		MERGE	dbo.LicenseeProduct l
		USING	(SELECT * FROM @tblProduct) t
			ON	l.ProductId = t.ProductId
				AND l.LicenseeId = @LicenseeId
		WHEN MATCHED AND (l.LaunchDate <> t.LaunchDate OR ISNULL(l.TerminationDate, '') <> ISNULL(t.TerminationDate, '')) THEN UPDATE SET l.LaunchDate = t.LaunchDate, l.TerminationDate = t.TerminationDate
		WHEN NOT MATCHED BY TARGET THEN INSERT (LicenseeId, ProductId, LaunchDate, TerminationDate) VALUES (@LicenseeId, t.ProductId, t.LaunchDate, t.TerminationDate)
		WHEN NOT MATCHED BY SOURCE AND l.LicenseeId = @LicenseeId THEN DELETE;
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 100
		RETURN
	END CATCH
	
	-- Insert feature
	IF @LicFeature IS NOT NULL
	BEGIN TRY
		INSERT INTO @tblFeature(
				FeatureId
				,LaunchDate
				,TerminationDate
		)
		SELECT	t.c.value('@id','int')
				,t.c.value('@launchdate', 'datetime') AS LaunchDate
				,t.c.value('@terminationdate', 'datetime') AS TerminationDate
		FROM	@LicFeature.nodes('root/row') t(c)
		
		MERGE	dbo.LicenseeFeature l
		USING	(SELECT * FROM @tblFeature) t
			ON	l.FeatureId = t.FeatureId
				AND l.LicenseeId = @LicenseeId
		WHEN MATCHED AND (l.LaunchDate <> t.LaunchDate OR ISNULL(l.TerminationDate, '') <> ISNULL(t.TerminationDate, '')) THEN UPDATE SET l.LaunchDate = t.LaunchDate, l.TerminationDate = t.TerminationDate
		WHEN NOT MATCHED BY TARGET THEN INSERT (LicenseeId, FeatureId, LaunchDate, TerminationDate) VALUES (@LicenseeId, t.FeatureId, t.LaunchDate, TerminationDate)
		WHEN NOT MATCHED BY SOURCE AND l.LicenseeId = @LicenseeId THEN DELETE;
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 101
		RETURN
	END CATCH

	SELECT @ErrCode = 0
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeInfoUpd_Step2_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeInfoUpd_Step2_xtest    Script Date: 11/11/2016 10:29:58 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeInfoUpd_Step2_xtest]
	@LicenseeId				INT
	,@LicProduct			XML				= NULL
	,@LicFeature			XML				= NULL
	
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150505
	Task: Update product & feature - Step2  [Redmine:#30959]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160511@Percy: Change type of input param @LicFeature [RedmineID: #56935]
	
	Param's Explanation:
	- @LicProduct, @LicFeature: list of product, feature
				<root>
					<row id="1" launchdate="2014-12-19" terminationdate="2016-05-11"/>
					<row id="3" launchdate="2014-12-19"/>
				</root>
	
	- @ErrCode:
		= 0: 
		> 0: Specific Error.
  
	- @ErrMsg: Error description.
	
	
 */
BEGIN
	SET NOCOUNT ON

	DECLARE @tblProduct TABLE (ProductId TINYINT, LaunchDate DATETIME, TerminationDate DATETIME)
	DECLARE @tblFeature TABLE (FeatureId TINYINT, LaunchDate DATETIME, TerminationDate DATETIME)
	
	-- Insert product
	IF @LicProduct IS NOT NULL
	BEGIN TRY
		INSERT INTO @tblProduct(
				ProductId
				,LaunchDate
				,TerminationDate
		)
		SELECT	t.c.value('@id','int')
				,t.c.value('@launchdate', 'datetime') AS LaunchDate
				,t.c.value('@terminationdate', 'datetime') AS TerminationDate
		FROM	@LicProduct.nodes('root/row') t(c)
		
		MERGE	dbo.LicenseeProduct l
		USING	(SELECT * FROM @tblProduct) t
			ON	l.ProductId = t.ProductId
				AND l.LicenseeId = @LicenseeId
		WHEN MATCHED AND (l.LaunchDate <> t.LaunchDate OR ISNULL(l.TerminationDate, '') <> ISNULL(t.TerminationDate, '')) THEN UPDATE SET l.LaunchDate = t.LaunchDate, l.TerminationDate = t.TerminationDate
		WHEN NOT MATCHED BY TARGET THEN INSERT (LicenseeId, ProductId, LaunchDate, TerminationDate) VALUES (@LicenseeId, t.ProductId, t.LaunchDate, t.TerminationDate)
		WHEN NOT MATCHED BY SOURCE AND l.LicenseeId = @LicenseeId THEN DELETE;
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 100
		RETURN
	END CATCH
	
	-- Insert feature
	IF @LicFeature IS NOT NULL
	BEGIN TRY
		INSERT INTO @tblFeature(
				FeatureId
				,LaunchDate
				,TerminationDate
		)
		SELECT	t.c.value('@id','int')
				,t.c.value('@launchdate', 'datetime') AS LaunchDate
				,t.c.value('@terminationdate', 'datetime') AS TerminationDate
		FROM	@LicFeature.nodes('root/row') t(c)
		
		MERGE	dbo.LicenseeFeature l
		USING	(SELECT * FROM @tblFeature) t
			ON	l.FeatureId = t.FeatureId
				AND l.LicenseeId = @LicenseeId
		WHEN MATCHED AND (l.LaunchDate <> t.LaunchDate OR ISNULL(l.TerminationDate, '') <> ISNULL(t.TerminationDate, '')) THEN UPDATE SET l.LaunchDate = t.LaunchDate, l.TerminationDate = t.TerminationDate
		WHEN NOT MATCHED BY TARGET THEN INSERT (LicenseeId, FeatureId, LaunchDate, TerminationDate) VALUES (@LicenseeId, t.FeatureId, t.LaunchDate, TerminationDate)
		WHEN NOT MATCHED BY SOURCE AND l.LicenseeId = @LicenseeId THEN DELETE;
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 101
		RETURN
	END CATCH

	SELECT @ErrCode = 0
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeInfoUpd_Step3]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeInfoUpd_Step3    Script Date: 8/15/2017 4:11:07 AM ******/
CREATE PROCEDURE [dbo].[OIC_LicenseeInfoUpd_Step3]
	@LicenseeId		INT
	,@AMUserId		INT
	,@PMUserId		INT
	,@oldAMUserId	INT
	,@oldPMUserId	INT
	,@AMDisplayName	VARCHAR(50)
	,@PMDisplayName	VARCHAR(50)
	,@LicAccount	XML				= NULL
	,@InternalURL	VARCHAR(3000)	= NULL
	
	,@UserId		INT
	,@Language		VARCHAR(10)		= 'E'
	,@IP			VARCHAR(50)		= NULL
	,@ErrCode		INT				= 0			OUTPUT
	,@ErrMsg		VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150505
	Task: Update internal person in charge - Step3 [Redmine:#27752]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20170517@Percy: Add Internal backend URL [RedmineID: #74330]
		- 20170802@Percy: Add Url testing account - add element into @LicAccount [RedmineID: #80712]
		- 20170809@Percy: Extend Url length [RedmineID: #81392]
	
	Param's Explanation:
	* @LicAccount:
				<root>
					<row order="1" type="1" username="webaccount" password="abc" url="https://" />
					<row order="1" type="2" username="csd" password="1234" url="https://" />
					<row order="1" type="3" username="training" password="12abc" url="https://" />
				</root>
	* @ErrCode:
		= 0: 
		> 0: Specific Error.
  
	* @ErrMsg: Error description.
 */
BEGIN
	SET NOCOUNT ON

	-- Internal Backend URL
	BEGIN TRY
		UPDATE dbo.Licensee WITH(ROWLOCK, UPDLOCK)
		SET InternalURL = @InternalURL
		WHERE LicenseeId = @LicenseeId
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 100
		RETURN
	END CATCH

	DECLARE @tblLicAccount TABLE (UserName NVARCHAR(50), UserPwd NVARCHAR(50), AccountType TINYINT, [Order] TINYINT, Url VARCHAR(3000))
	
	-- Update AM
	IF @oldAMUserId <> @AMUserId
	BEGIN TRY
		DELETE 
		FROM	dbo.UserLicensee WITH(ROWLOCK, UPDLOCK) 
		WHERE	LicenseeId = @LicenseeId 
				AND UserId = @oldAMUserId
		
		INSERT INTO dbo.UserLicensee( UserId, LicenseeId ) VALUES (@AMUserId, @LicenseeId)
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 100
		RETURN
	END CATCH
	
	-- Update PM
	IF @oldPMUserId <> @PMUserId
	BEGIN TRY		
		DELETE 
		FROM	dbo.UserLicensee WITH(ROWLOCK, UPDLOCK) 
		WHERE	LicenseeId = @LicenseeId 
				AND UserId = @oldPMUserId
		
		INSERT INTO dbo.UserLicensee( UserId, LicenseeId ) VALUES (@PMUserId, @LicenseeId)
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 101
		RETURN
	END CATCH
	
	-- Update Account
	IF @LicAccount IS NOT NULL
	BEGIN TRY
		INSERT INTO @tblLicAccount(
				UserName
				,UserPwd
				,AccountType
				,[Order]
				,Url
		)
		SELECT	t.c.value('@username','nvarchar(50)')
				,t.c.value('@password','nvarchar(50)')
				,t.c.value('@type','tinyint')
				,t.c.value('@order','tinyint')
				,t.c.value('@url','varchar(3000)')
		FROM @LicAccount.nodes('root/row') t(c) 
				
		MERGE	dbo.LicenseeAccountInfo l
		USING	(SELECT * FROM @tblLicAccount) t
			ON	l.[Order] = t.[Order]
				AND l.LicenseeId = @LicenseeId
				AND l.AccountType = t.AccountType
		WHEN MATCHED AND (l.UserName <> t.UserName OR l.UserPwd <> t.UserPwd OR l.Url <> t.Url)
			THEN UPDATE SET l.UserName = t.UserName, l.UserPwd = t.UserPwd, l.Url = t.Url
		WHEN NOT MATCHED BY TARGET
			THEN INSERT (LicenseeId, UserName, UserPwd, AccountType, [Order], Url) VALUES (@LicenseeId, t.UserName, t.UserPwd, t.AccountType, t.[Order], t.Url)
		WHEN NOT MATCHED BY SOURCE AND l.LicenseeId = @LicenseeId THEN DELETE;
	END TRY
	BEGIN CATCH
			SELECT @ErrCode = 102
			RETURN
	END CATCH

	SELECT @ErrCode = 0
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeInfoUpd_Step3_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OIC_LicenseeInfoUpd_Step3_xtest]
	@LicenseeId		INT
	,@AMUserId		INT
	,@PMUserId		INT
	,@oldAMUserId	INT
	,@oldPMUserId	INT
	,@AMDisplayName	VARCHAR(50)
	,@PMDisplayName	VARCHAR(50)
	,@LicAccount	XML				= NULL
	,@InternalURL	VARCHAR(3000)	= NULL
	
	,@UserId		INT
	,@Language		VARCHAR(10)		= 'E'
	,@IP			VARCHAR(50)		= NULL
	,@ErrCode		INT				= 0			OUTPUT
	,@ErrMsg		VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150505
	Task: Update internal person in charge - Step3 [Redmine:#27752]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20170517@Percy: Add Internal backend URL [RedmineID: #74330]
		- 20170802@Percy: Add Url testing account - add element into @LicAccount [RedmineID: #80712]
		- 20170809@Percy: Extend Url length [RedmineID: #81392]
	
	Param's Explanation:
	* @LicAccount:
				<root>
					<row order="1" type="1" username="webaccount" password="abc" url="https://" />
					<row order="1" type="2" username="csd" password="1234" url="https://" />
					<row order="1" type="3" username="training" password="12abc" url="https://" />
				</root>
	* @ErrCode:
		= 0: 
		> 0: Specific Error.
  
	* @ErrMsg: Error description.
 */
BEGIN
	SET NOCOUNT ON

	-- Internal Backend URL
	BEGIN TRY
		UPDATE dbo.Licensee WITH(ROWLOCK, UPDLOCK)
		SET InternalURL = @InternalURL
		WHERE LicenseeId = @LicenseeId
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 100
		RETURN
	END CATCH

	DECLARE @tblLicAccount TABLE (UserName NVARCHAR(50), UserPwd NVARCHAR(50), AccountType TINYINT, [Order] TINYINT, Url VARCHAR(3000))
	
	-- Update AM
	IF @oldAMUserId <> @AMUserId
	BEGIN TRY
		DELETE 
		FROM	dbo.UserLicensee WITH(ROWLOCK, UPDLOCK) 
		WHERE	LicenseeId = @LicenseeId 
				AND UserId = @oldAMUserId
		
		INSERT INTO dbo.UserLicensee( UserId, LicenseeId ) VALUES (@AMUserId, @LicenseeId)
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 100
		RETURN
	END CATCH
	
	-- Update PM
	IF @oldPMUserId <> @PMUserId
	BEGIN TRY		
		DELETE 
		FROM	dbo.UserLicensee WITH(ROWLOCK, UPDLOCK) 
		WHERE	LicenseeId = @LicenseeId 
				AND UserId = @oldPMUserId
		
		INSERT INTO dbo.UserLicensee( UserId, LicenseeId ) VALUES (@PMUserId, @LicenseeId)
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 101
		RETURN
	END CATCH
	
	-- Update Account
	IF @LicAccount IS NOT NULL
	BEGIN TRY
		INSERT INTO @tblLicAccount(
				UserName
				,UserPwd
				,AccountType
				,[Order]
				,Url
		)
		SELECT	t.c.value('@username','nvarchar(50)')
				,t.c.value('@password','nvarchar(50)')
				,t.c.value('@type','tinyint')
				,t.c.value('@order','tinyint')
				,t.c.value('@url','varchar(3000)')
		FROM @LicAccount.nodes('root/row') t(c) 
				
		MERGE	dbo.LicenseeAccountInfo l
		USING	(SELECT * FROM @tblLicAccount) t
			ON	l.[Order] = t.[Order]
				AND l.LicenseeId = @LicenseeId
				AND l.AccountType = t.AccountType
		WHEN MATCHED AND (l.UserName <> t.UserName OR l.UserPwd <> t.UserPwd OR l.Url <> t.Url)
			THEN UPDATE SET l.UserName = t.UserName, l.UserPwd = t.UserPwd, l.Url = t.Url
		WHEN NOT MATCHED BY TARGET
			THEN INSERT (LicenseeId, UserName, UserPwd, AccountType, [Order], Url) VALUES (@LicenseeId, t.UserName, t.UserPwd, t.AccountType, t.[Order], t.Url)
		WHEN NOT MATCHED BY SOURCE AND l.LicenseeId = @LicenseeId THEN DELETE;
	END TRY
	BEGIN CATCH
			SELECT @ErrCode = 102
			RETURN
	END CATCH

	SELECT @ErrCode = 0
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeInfoUpd_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OIC_LicenseeInfoUpd_xtest]	
	@LicenseeId				INT
	,@UpdateStep1			BIT				= 1
	,@LicenseeTypeId		TINYINT			= NULL
	,@SiteName				NVARCHAR(50)	= NULL
	,@CompanyName			NVARCHAR(50)	= NULL
	,@LicenseeStatusId		TINYINT			= NULL
	,@IsReseller			BIT				= 0
	,@IsChineseMarketOnly	BIT				= 0
	,@SoftLaunch			DATETIME		= NULL
	,@FullLaunch			DATETIME		= NULL
	,@MainUrl				VARCHAR(3000)	= NULL
	,@APIUrl				VARCHAR(3000)	= NULL
	,@LicBackUpLink			XML				= NULL
	,@HasMainContact		BIT				= 0
	,@MainContactName		NVARCHAR(50)	= NULL
	,@Position				NVARCHAR(50)	= NULL
	,@Department			NVARCHAR(50)	= NULL
	,@Email					VARCHAR(50)		= NULL
	,@PhoneNumber			VARCHAR(50)		= NULL
	,@Skype					VARCHAR(50)		= NULL
	,@MainContactRemark		NVARCHAR(300)	= NULL
	,@LocationId			INT				= NULL
	,@CurrenciesOffered		VARCHAR(100)	= NULL
	,@LicTargetMarket		VARCHAR(1000)	= NULL
	,@LicLanguage			XML				= NULL
	,@LicLanguageSB			XML				= NULL
	,@LicService			XML				= NULL
	,@LicRestrictCountry	VARCHAR(1000)	= NULL
	,@RestrictCountryRemark	NVARCHAR(500)	= NULL		
	,@Remark				NVARCHAR(300)	= NULL
	
	,@UpdateStep2			BIT				= 1
	,@LicProduct			XML				= NULL
	,@LicFeature			XML				= NULL
	
	,@UpdateStep3			BIT				= 1
	,@AMUserId				INT				= NULL
	,@PMUserId				INT				= NULL
	,@LicAccount			XML				= NULL
	,@InternalURL			VARCHAR(3000)	= NULL
	
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= ''		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2015-04-05
	Task: Update Licensee [Redmine:#30959]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160511@Percy: Change type of input param @LicFeature [RedmineID: #56935]
		- 20160805@Percy: Expand length of params: @LicTargetMarket, @LicRestrictCountry [RedmineID: #62099]
		- 20160823@Percy: Add param: @LicLanguageSB - Sportbook offered language [RedmineID: #62883]
		- 20170517@Percy: Add Chinese Market Only and Internal Backend URL [RedmineID: #74330]
		- 20170802@Percy: Add Url testing account - add element into @LicAccount [RedmineID: #80712]
		- 20170809@Percy: Extend Url length [RedmineID: #81392]
		- 20170828@Scofield: Add Reseller [#82144]
	
	Param's Explanation:
	* @LicBackupLink
		<root>
			<row val="link1" />
			<row val="link2" />
		</root>
	* @LicService: List of Services
		Format:
				<root>
					<row pid="1" val="kathy.nguyen" />
					<row pid="2" val="password" />
					<row pid="3" val="http:..." />
					<row pid="4" val="http:..." />
				</root>
	* @LicLanguage, @LicLanguageSB
		Format:
				<root>
					<row id="1" />
					<row id="2" />
				</root>
	* @LicProduct, @LicFeature: list of product, feature
				<root>
					<row id="1" launchdate="2014-12-19" terminationdate="2016-05-11"/>
					<row id="3" launchdate="2014-12-19"/>
				</root>
				
	* @LicAccount:
				<root>
					<row order="1" type="1" username="webaccount" password="abc" url="https://" />
					<row order="1" type="2" username="csd" password="1234" url="https://" />
					<row order="1" type="3" username="training" password="12abc" url="https://" />
				</root>
				
	* @CurrenciesOffered, @LicTargetMarket, @LicRestrictCountry
	* @ErrCode:
		= 0: 
		> 0: Specific Error.
  
	* @ErrMsg: Error description.
	
	
	* Log:
	
 */
BEGIN
	SET NOCOUNT ON
	
	-- check licensee name
	EXEC dbo.OIC_LicenseeNameChecking
		@SiteName	= @SiteName
		,@LicenseeId = @LicenseeId
		,@Language	= @Language
		,@ErrCode	= @ErrCode	OUTPUT
		,@ErrMsg	= @ErrMsg	OUTPUT
	
	IF @ErrCode <> 0
	BEGIN
		SELECT @ErrCode, @ErrMsg
		RETURN
	END

	-- For write log
	DECLARE 
		@startRun					DATETIME
		,@endRun					DATETIME
		,@duration					INT
		,@logSPData					NVARCHAR(MAX)
		,@logSPOlddata				NVARCHAR(MAX)
		,@xml						XML
		,@procName					VARCHAR(200)
		-- log step 1
		,@log_backupLink			XML
		,@log_maincontact			XML
		,@log_currency				XML
		,@log_targetedMarket		XML
		,@log_restrictedLocation	XML
		,@log_language				XML
		,@log_languageSB			XML
		,@log_service				XML
		-- log step 2
		,@log_product				XML
		,@log_feature				XML
		-- log step 3
		,@log_account				XML
		,@oldAMUserId				INT
		,@oldPMUserId				INT
		,@AMDisplayName				VARCHAR(50)
		,@PMDisplayName				VARCHAR(50)
		,@location					VARCHAR(50)
	
	SET @startRun = GETDATE()

	-- Get data before update
	IF @UpdateStep1 = 1
	BEGIN
		SET @log_backupLink = (	SELECT	lu.UrlValue AS '@lbul'
								FROM	dbo.UrlBackup AS lu WITH (NOLOCK)
								WHERE	lu.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('bk')		
							)
	
		SET @log_maincontact  = (SELECT	c.ContactID			AS '@cid'
										,c.ContactName		AS '@cn'
										,c.ContactPosition	AS '@cp'
										,c.ContactDepartment AS '@cd'
										,c.ContactEmail		AS '@ce'
										,c.ContactSkype		AS '@cs'
										,c.ContactPhoneNumber	AS '@cpn'
										,c.IsMain			AS '@cim'
										,c.Remark			AS '@crm'
								FROM	dbo.Contact c
								WHERE	licenseeid = @LicenseeId AND c.IsMain = 1
								FOR XML PATH('row'), ROOT('lc')	
							)
		SET @log_currency = (
								SELECT	e.exchangeid AS '@cid'
										,e.Code AS '@cur'
								FROM dbo.LicenseeCurrency AS lc WITH (NOLOCK)
									INNER JOIN bodb02.dbo.Exchange AS e WITH(NOLOCK) 
										ON e.exchangeid = lc.CurrencyId
								WHERE	lc.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('cr')	
							)
		SET @log_targetedMarket = (
								SELECT  lo.LocationId AS '@tmid'
										,lo.LocationName AS '@tmn'
								FROM dbo.LicenseeLocationLimit AS ll WITH (NOLOCK)
									INNER JOIN dbo.Location AS lo WITH(NOLOCK) 
										ON lo.LocationId = ll.LocationLimitId 
										AND ll.LicenseeLocationType = 1
								WHERE	ll.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('tm')	
							)
		SET @log_restrictedLocation = (
								SELECT lo.LocationId AS '@rlid'
										,lo.LocationName AS '@rln'
								FROM dbo.LicenseeLocationLimit AS ll WITH (NOLOCK)
									INNER JOIN dbo.Location AS lo WITH(NOLOCK) 
										ON lo.LocationId = ll.LocationLimitId 
										AND ll.LicenseeLocationType = 2
								WHERE	ll.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('rl')		
							)
						
		SET @log_Language = (
								SELECT	la.LanguageId AS '@llid'
										,la.LanguageName AS '@lln'
								FROM dbo.LicenseeLanguage AS ll WITH (NOLOCK)
									INNER JOIN dbo.Language AS la WITH(NOLOCK) 
										ON la.LanguageId = ll.LanguageId
								WHERE	ll.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('ll')	
							)
						
		SET @log_LanguageSB = (
								SELECT	la.LanguageId AS '@llidsb'
										,la.LanguageName AS '@llnsb'
								FROM dbo.LicenseeProductLanguage AS ll WITH (NOLOCK)
									INNER JOIN dbo.Language AS la WITH(NOLOCK) 
										ON la.LanguageId = ll.LanguageId
								WHERE	ll.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('llsb')	
							)
	
		SET @log_service = (	SELECT	s.ServiceId				AS '@lsid'
										,s.ServiceName				AS '@lsn'
										,lp.PropertyId				as '@lspid'
										,lp.PropertyValue as '@lspv'
								FROM dbo.LicenseeProperty lp
									INNER JOIN dbo.Property p
										ON	p.PropertyId = lp.PropertyId
									INNER JOIN dbo.Service s 
										ON	s.ServiceId = p.ServiceId
								WHERE	licenseeid = @LicenseeId
								FOR XML PATH('row'), ROOT('ls')	
							)
		SELECT @location = LocationName FROM dbo.Location WITH(NOLOCK) WHERE LocationId = (SELECT LicenseeLocationId FROM dbo.Licensee WITH(NOLOCK) WHERE LicenseeId = @LicenseeId)
	END
	
	IF @UpdateStep2 = 1
	BEGIN
		SET @log_product = (
							SELECT	p.ProductId AS '@lpid'
									,p.ProductName AS '@lpn'
									,p.[Order] AS '@lpod'
									,lp.LaunchDate AS '@lpl'
									,lp.TerminationDate AS '@lpt'
							FROM	dbo.LicenseeProduct AS lp WITH (NOLOCK)
								INNER JOIN dbo.Product AS p WITH(NOLOCK) 
									ON	p.ProductId = lp.ProductId
							WHERE	lp.LicenseeId = @LicenseeId
							FOR XML PATH('row'), ROOT('lp')	
						)
		SET @log_feature = (
							SELECT	f.FeatureId AS '@lfid'
									,f.FeatureName AS '@lfn'
									,lf.LaunchDate AS '@lfl'
									,lf.TerminationDate AS '@lft'
							FROM	dbo.LicenseeFeature AS lf WITH (NOLOCK)
								INNER JOIN dbo.Feature AS f WITH(NOLOCK) 
									ON	f.FeatureId = lf.FeatureId
							WHERE	lf.LicenseeId = @LicenseeId
							FOR XML PATH('row'), ROOT('lf')	
						)
	END
	
	IF @UpdateStep3 = 1
	BEGIN
		SELECT @oldPMUserId = ul.UserId, @PMDisplayName = ui.DisplayName
		FROM dbo.UserInfo ui WITH(NOLOCK)
			INNER JOIN dbo.UserLicensee ul WITH(NOLOCK) ON ui.UserId = ul.UserId AND ul.LicenseeId = @licenseeId AND ui.PositionId = 5 -- PM
			
		SELECT @oldAMUserId = ul.UserId, @AMDisplayName = ui.DisplayName
		FROM dbo.UserInfo ui WITH(NOLOCK)
			INNER JOIN dbo.UserLicensee ul WITH(NOLOCK) ON ui.UserId = ul.UserId AND ul.LicenseeId = @licenseeId AND ui.PositionId = 6 -- AM			
	
		SET @log_account = (	SELECT	la.AccountId	AS '@laid'
										,la.UserName	AS '@lan'
										,la.UserPwd		AS '@lap'
										,la.AccountType AS '@lat'
										,la.[Order]		AS '@lod'
										,la.Url			AS '@lu'
								FROM	dbo.LicenseeAccountInfo AS la WITH (NOLOCK)
								WHERE	la.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('la')
						)
	END

	SET @xml = (SELECT	@LicenseeId					AS '@lid'
							,t.LicenseeTypeName			AS '@tn'
							,l.LicenseeName				AS '@ln'
							,l.LicenseeCompanyName		AS '@cn'
							,s.LicenseeStatusName		AS '@sn'
							,l.SoftLaunch				AS '@sl'
							,l.FullLaunch				AS '@fl'
							,l.MainUrl					AS '@mu'
							,l.APILinkageUrl			AS '@au'
							,l.RestrictedLocationRemark	AS '@rlr'			
							,l.Remark					AS '@rm'
							,l.IsChineseMarketOnly		AS '@icm'
							,l.IsReseller				AS '@res'
							,l.InternalURL				AS '@iu'
							,@location					AS '@lc'
							,@AMDisplayName				AS '@amn'
							,@PMDisplayName				AS '@pmn'
							,@log_backupLink
							,@log_maincontact
							,@log_currency
							,@log_Language
							,@log_languageSB
							,@log_restrictedLocation
							,@log_targetedMarket
							,@log_service
							,@log_product
							,@log_feature
							,@log_account
					FROM dbo.Licensee AS l WITH (NOLOCK)
						INNER JOIN dbo.LicenseeStatus AS s WITH(NOLOCK) 
							ON	l.LicenseeStatusId = s.LicenseeStatusId
						INNER JOIN dbo.LicenseeType AS t WITH(NOLOCK) 
							ON	l.LicenseeTypeId = t.LicenseeTypeId
					WHERE	l.LicenseeId = @LicenseeId
					FOR XML PATH('r'), TYPE
				)
	
	SELECT @logSPOldData = CONVERT(NVARCHAR(MAX), @xml)
		
	-- Step1: Update general info
	IF @UpdateStep1 = 1
	BEGIN
		EXEC dbo.OIC_LicenseeInfoUpd_Step1_xtest
			@LicenseeId					= @LicenseeId
			,@LicenseeTypeId			= @LicenseeTypeId
			,@SiteName					= @SiteName
			,@CompanyName				= @CompanyName
			,@LicenseeStatusId			= @LicenseeStatusId
			,@IsReseller				= @IsReseller
			,@IsChineseMarketOnly		= @IsChineseMarketOnly
			,@SoftLaunch				= @SoftLaunch
			,@FullLaunch				= @FullLaunch
			,@MainUrl					= @MainUrl
			,@APIUrl					= @APIUrl
			,@LicBackUpLink				= @LicBackUpLink
			,@HasMainContact			= @HasMainContact
			,@MainContactName			= @MainContactName
			,@Position					= @Position
			,@Department				= @Department
			,@Email						= @Email
			,@PhoneNumber				= @PhoneNumber
			,@Skype						= @Skype
			,@MainContactRemark			= @MainContactRemark
			,@LocationId				= @LocationId
			,@CurrenciesOffered			= @CurrenciesOffered
			,@LicTargetMarket			= @LicTargetMarket
			,@LicLanguage				= @LicLanguage
			,@LicLanguageSB				= @LicLanguageSB
			,@LicService				= @LicService
			,@LicRestrictCountry		= @LicRestrictCountry
			,@RestrictCountryRemark		= @RestrictCountryRemark		
			,@Remark					= @Remark
			
			,@UserId					= @UserId
			,@Language					= @Language
			,@IP						= @IP
			,@ErrCode					= @ErrCode		OUTPUT
			,@ErrMsg					= @ErrMsg		OUTPUT		
		
		IF @ErrCode <> 0
		BEGIN
			SELECT	@ErrCode = @ErrCode
					,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](6, @Language) -- Edit client failed at step 1
		END
		ELSE
		BEGIN
			-- get data after Step 1
			SET @log_backupLink = (	SELECT	lu.UrlValue AS '@lbul'
									FROM	dbo.UrlBackup AS lu WITH (NOLOCK)
									WHERE	lu.LicenseeId = @LicenseeId
									FOR XML PATH('row'), ROOT('bk')		
								)
	
			SET @log_maincontact  = (SELECT	c.ContactID			AS '@cid'
											,c.ContactName		AS '@cn'
											,c.ContactPosition	AS '@cp'
											,c.ContactDepartment AS '@cd'
											,c.ContactEmail		AS '@ce'
											,c.ContactSkype		AS '@cs'
											,c.ContactPhoneNumber	AS '@cpn'
											,c.IsMain			AS '@cim'
											,c.Remark			AS '@crm'
									FROM	dbo.Contact c
									WHERE	licenseeid = @LicenseeId AND c.IsMain = 1
									FOR XML PATH('row'), ROOT('lc')	
								)
			SET @log_currency = (
									SELECT	e.exchangeid AS '@cid'
											,e.Code AS '@cur'
									FROM dbo.LicenseeCurrency AS lc WITH (NOLOCK)
										INNER JOIN bodb02.dbo.Exchange AS e WITH(NOLOCK) 
											ON e.exchangeid = lc.CurrencyId
									WHERE	lc.LicenseeId = @LicenseeId
									FOR XML PATH('row'), ROOT('cr')	
								)
			SET @log_targetedMarket = (
									SELECT  lo.LocationId AS '@tmid'
											,lo.LocationName AS '@tmn'
									FROM dbo.LicenseeLocationLimit AS ll WITH (NOLOCK)
										INNER JOIN dbo.Location AS lo WITH(NOLOCK) 
											ON lo.LocationId = ll.LocationLimitId 
											AND ll.LicenseeLocationType = 1
									WHERE	ll.LicenseeId = @LicenseeId
									FOR XML PATH('row'), ROOT('tm')	
								)
			SET @log_restrictedLocation = (
									SELECT lo.LocationId AS '@rlid'
											,lo.LocationName AS '@rln'
									FROM dbo.LicenseeLocationLimit AS ll WITH (NOLOCK)
										INNER JOIN dbo.Location AS lo WITH(NOLOCK) 
											ON lo.LocationId = ll.LocationLimitId 
											AND ll.LicenseeLocationType = 2
									WHERE	ll.LicenseeId = @LicenseeId
									FOR XML PATH('row'), ROOT('rl')		
								)
						
			SET @log_Language = (
									SELECT	la.LanguageId AS '@llid'
											,la.LanguageName AS '@lln'
									FROM dbo.LicenseeLanguage AS ll WITH (NOLOCK)
										INNER JOIN dbo.Language AS la WITH(NOLOCK) 
											ON la.LanguageId = ll.LanguageId
									WHERE	ll.LicenseeId = @LicenseeId
									FOR XML PATH('row'), ROOT('ll')	
								)
						
			SET @log_LanguageSB = (
									SELECT	la.LanguageId AS '@llidsb'
											,la.LanguageName AS '@llnsb'
									FROM dbo.LicenseeProductLanguage AS ll WITH (NOLOCK)
										INNER JOIN dbo.Language AS la WITH(NOLOCK) 
											ON la.LanguageId = ll.LanguageId
									WHERE	ll.LicenseeId = @LicenseeId
									FOR XML PATH('row'), ROOT('llsb')	
								)
	
			SET @log_service = (	SELECT	s.ServiceId				AS '@lsid'
											,s.ServiceName				AS '@lsn'
											,lp.PropertyId				as '@lspid'
											,lp.PropertyValue as '@lspv'
									FROM dbo.LicenseeProperty lp
										INNER JOIN dbo.Property p
											ON	p.PropertyId = lp.PropertyId
										INNER JOIN dbo.Service s 
											ON	s.ServiceId = p.ServiceId
									WHERE	licenseeid = @LicenseeId
									FOR XML PATH('row'), ROOT('ls')	
								)
			SELECT @location = LocationName FROM dbo.Location WITH(NOLOCK) WHERE LocationId = @LocationId
		END
	END
	-- END Step1

	-- Step2: Update product & feature 
	IF @UpdateStep2 = 1
	BEGIN
		EXEC dbo.OIC_LicenseeInfoUpd_Step2
			@LicenseeId		= @LicenseeId
			,@LicProduct	= @LicProduct
			,@LicFeature	= @LicFeature
		
			,@UserId		= @UserId
			,@Language		= @Language
			,@IP			= @IP
			,@ErrCode		= @ErrCode	OUTPUT
			,@ErrMsg		= @ErrMsg	OUTPUT
		
		IF @ErrCode <> 0
		BEGIN
			SELECT	@ErrCode = @ErrCode
					,@ErrMsg =  @ErrMsg + [dbo].[f_Get_MsgNamebyMsgID](7, @Language) -- Edit client failed at step 2
		END
		ELSE
		BEGIN
			-- get data after Step 2
			SET @log_product = (
								SELECT	p.ProductId AS '@lpid'
										,p.ProductName AS '@lpn'
										,p.[Order] AS '@lpod'
										,lp.LaunchDate AS '@lpl'
										,lp.TerminationDate AS '@lpt'
								FROM	dbo.LicenseeProduct AS lp WITH (NOLOCK)
									INNER JOIN dbo.Product AS p WITH(NOLOCK) 
										ON	p.ProductId = lp.ProductId
								WHERE	lp.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('lp')	
							)
			SET @log_feature = (
								SELECT	f.FeatureId AS '@lfid'
										,f.FeatureName AS '@lfn'
										,lf.LaunchDate AS '@lfl'
										,lf.TerminationDate AS '@lft'
								FROM	dbo.LicenseeFeature AS lf WITH (NOLOCK)
									INNER JOIN dbo.Feature AS f WITH(NOLOCK) 
										ON	f.FeatureId = lf.FeatureId
								WHERE	lf.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('lf')	
							)
		END
	END	
	-- END Step2
	
	-- Step3: Internal Person in Charge 
	IF @UpdateStep3 = 1
	BEGIN
		EXEC dbo.OIC_LicenseeInfoUpd_Step3
			@LicenseeId			= @LicenseeId
			,@AMUserId			= @AMUserId
			,@PMUserId			= @PMUserId
			,@oldAMUserId		= @oldAMUserId
			,@oldPMUserId		= @oldPMUserId
			,@AMDisplayName		= @AMDisplayName
			,@PMDisplayName		= @PMDisplayName
			,@LicAccount		= @LicAccount
			,@InternalURL		= @InternalURL
			
			,@UserId			= @UserId
			,@Language			= @Language
			,@IP				= @IP
			,@ErrCode			= @ErrCode	OUTPUT
			,@ErrMsg			= @ErrMsg	OUTPUT
			
		IF @ErrCode <> 0
		BEGIN
			SELECT	@ErrCode = @ErrCode
					,@ErrMsg = @ErrMsg + [dbo].[f_Get_MsgNamebyMsgID](8, @Language) -- Edit client failed at step 3
		END
		ELSE
		BEGIN
			-- get data after Step 3
			SELECT @PMDisplayName = ui.DisplayName
			FROM	dbo.UserInfo ui WITH(NOLOCK)
			WHERE	ui.UserId = @PMUserId
						AND ui.PositionId = 5 -- PM
			
			SELECT @AMDisplayName = ui.DisplayName
			FROM	dbo.UserInfo ui WITH(NOLOCK)
			WHERE	ui.UserId = @AMUserId
						AND ui.PositionId = 6 -- AM
				
			SET @log_account = (
								SELECT	la.AccountId	AS '@laid'
										,la.UserName	AS '@lan'
										,la.UserPwd		AS '@lap'
										,la.AccountType AS '@lat'
										,la.[Order]		AS '@lod'
										,la.Url			AS '@lu'
								FROM dbo.LicenseeAccountInfo AS la WITH (NOLOCK)
								WHERE	la.LicenseeId = @LicenseeId
								FOR XML PATH('row'), ROOT('la')	
							)
		END
	END
	--END Step3

	-- Write log
	SET @xml = (		SELECT	@LicenseeId					AS '@lid'
								,t.LicenseeTypeName			AS '@tn'
								,l.LicenseeName				AS '@ln'
								,l.LicenseeCompanyName		AS '@cn'
								,s.LicenseeStatusName		AS '@sn'
								,l.SoftLaunch				AS '@sl'
								,l.FullLaunch				AS '@fl'
								,l.MainUrl					AS '@mu'
								,l.APILinkageUrl			AS '@au'
								,l.RestrictedLocationRemark	AS '@rlr'			
								,l.Remark					AS '@rm'
								,l.IsChineseMarketOnly		AS '@icm'
								,l.IsReseller				AS '@res'
								,l.InternalURL				AS '@iu'
								,@location					AS '@lc'
								,@AMDisplayName				AS '@amn'
								,@PMDisplayName				AS '@pmn'
								,@log_backupLink
								,@log_maincontact
								,@log_currency
								,@log_Language
								,@log_LanguageSB
								,@log_restrictedLocation
								,@log_targetedMarket
								,@log_service
								,@log_product
								,@log_feature
								,@log_account
						FROM dbo.Licensee AS l WITH (NOLOCK)
							INNER JOIN dbo.LicenseeStatus AS s WITH(NOLOCK) 
								ON	l.LicenseeStatusId = s.LicenseeStatusId
							INNER JOIN dbo.LicenseeType AS t WITH(NOLOCK) 
								ON	l.LicenseeTypeId = t.LicenseeTypeId
						WHERE	l.LicenseeId = @LicenseeId
						FOR XML PATH('r'), TYPE
				)
	
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOlddata
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeListAll]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeListAll    Script Date: 1/8/2018 10:37:33 PM ******/
CREATE PROCEDURE [dbo].[OIC_LicenseeListAll]
AS
/*
	Created by: Scofield
	Date: 20171129
	Task: get all licensee [Redmine:#84004]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20171130@Scofield: create OIC_LicenseeListAll
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT lt.LicenseeTypeId, lt.LicenseeTypeName, l.LicenseeId, l.LicenseeName
	FROM dbo.Licensee l WITH(NOLOCK)
	INNER JOIN dbo.LicenseeType lt WITH(NOLOCK) ON l.LicenseeTypeId = lt.LicenseeTypeId
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeListAll_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OIC_LicenseeListAll_xtest]
AS
/*
	Created by: Scofield
	Date: 20171129
	Task: get all licensee [Redmine:#84004]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20171130@Scofield: create OIC_LicenseeListAll_xtest
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT lt.LicenseeTypeId, lt.LicenseeTypeName, l.LicenseeId, l.LicenseeName
	FROM dbo.Licensee l WITH(NOLOCK)
	INNER JOIN dbo.LicenseeType lt WITH(NOLOCK) ON l.LicenseeTypeId = lt.LicenseeTypeId
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeListByCategory]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeListByCategory    Script Date: 6/14/2017 10:35:07 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeListByCategory    Script Date: 6/13/2017 9:18:45 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeListByCategory] 
    @CategoryId				TINYINT
    ,@UserId				INT
	,@IsChineseMarketOnly	BIT		= 0
   
AS

/*
    Created by: Kathy
    Date: 20150825
    Task: Licensee list belong to category [Redmine:#29610]
    DB: DBOIC.bodb_OIC
    
    Revisions:
		- 20160225@Percy: change sitename dropdown [Redmine: #52858]
		- 20170517@Percy: Add Chinese Market Only [RedmineID: #74330]
    
    Param's Explanation:
		
*/

BEGIN
    SET NOCOUNT ON

	SELECT l.LicenseeId, l.LicenseeName, l.LicenseeTypeId, lt.LicenseeTypeName
	FROM dbo.Licensee l WITH(NOLOCK)
		INNER JOIN dbo.UserLicenseeType ult WITH(NOLOCK) ON ult.LicenseeTypeId = l.LicenseeTypeId
		INNER JOIN dbo.LicenseeType lt WITH(NOLOCK) ON ult.LicenseeTypeId = lt.LicenseeTypeId
		INNER JOIN dbo.LicenseeCategoryAssigned	lca WITH(NOLOCK) ON l.LicenseeId = lca.LicenseeId
		INNER JOIN dbo.Contact c WITH(NOLOCK) ON l.LicenseeId = c.LicenseeId
		INNER JOIN dbo.CategoryContact cc WITH(NOLOCK) ON cc.ContactId = c.ContactId AND cc.CategoryId = lca.CategoryId
	WHERE
		ult.UserId = @UserId
		AND lca.CategoryId = @CategoryId
		AND (
			@IsChineseMarketOnly = 0
			OR l.IsChineseMarketOnly = @IsChineseMarketOnly
		)
		AND l.LicenseeStatusId = 3 -- Active
	GROUP BY l.LicenseeId, l.LicenseeName, l.LicenseeTypeId, lt.LicenseeTypeName              
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeListByCategory_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeListByCategory_xtest    Script Date: 6/13/2017 9:18:45 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeListByCategory_xtest] 
    @CategoryId				TINYINT
    ,@UserId				INT
	,@IsChineseMarketOnly	BIT		= 0
   
AS

/*
    Created by: Kathy
    Date: 20150825
    Task: Licensee list belong to category [Redmine:#29610]
    DB: DBOIC.bodb_OIC
    
    Revisions:
		- 20160225@Percy: change sitename dropdown [Redmine: #52858]
		- 20170517@Percy: Add Chinese Market Only [RedmineID: #74330]
    
    Param's Explanation:
		
*/

BEGIN
    SET NOCOUNT ON

	SELECT l.LicenseeId, l.LicenseeName, l.LicenseeTypeId, lt.LicenseeTypeName
	FROM dbo.Licensee l WITH(NOLOCK)
		INNER JOIN dbo.UserLicenseeType ult WITH(NOLOCK) ON ult.LicenseeTypeId = l.LicenseeTypeId
		INNER JOIN dbo.LicenseeType lt WITH(NOLOCK) ON ult.LicenseeTypeId = lt.LicenseeTypeId
		INNER JOIN dbo.LicenseeCategoryAssigned	lca WITH(NOLOCK) ON l.LicenseeId = lca.LicenseeId
		INNER JOIN dbo.Contact c WITH(NOLOCK) ON l.LicenseeId = c.LicenseeId
		INNER JOIN dbo.CategoryContact cc WITH(NOLOCK) ON cc.ContactId = c.ContactId AND cc.CategoryId = lca.CategoryId
	WHERE
		ult.UserId = @UserId
		AND lca.CategoryId = @CategoryId
		AND (
			@IsChineseMarketOnly = 0
			OR l.IsChineseMarketOnly = @IsChineseMarketOnly
		)
		AND l.LicenseeStatusId = 3 -- Active
	GROUP BY l.LicenseeId, l.LicenseeName, l.LicenseeTypeId, lt.LicenseeTypeName              
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeListByProduct]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeListByProduct    Script Date: 17/03/2016 9:28:13 AM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeListByProduct    Script Date: 17/03/2016 9:25:53 AM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeListByProduct    Script Date: 3/15/2016 10:50:20 AM ******/
CREATE PROCEDURE [dbo].[OIC_LicenseeListByProduct] 
    @ProductId			TINYINT
   ,@UserId				INT
AS
/*
    Created by: Kathy
    Date: 20150825
    Task: Licensee list belong to product [Redmine:#29610]
    DB: DBOIC.bodb_OIC
    
    Revisions:
		- 20160225@Percy: change sitename dropdown [Redmine: #52858]
    
    Param's Explanation:
		
*/
BEGIN
    SET NOCOUNT ON
    
    SELECT	LicenseeId, LicenseeName, LicenseeTypeId, LicenseeTypeName
    FROM	dbo.f_LicenseeBelongToProduct (@ProductId, @UserId)
   
END

GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeListByProduct_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeListByProduct_xtest    Script Date: 17/03/2016 9:28:13 AM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeListByProduct_xtest    Script Date: 17/03/2016 9:25:53 AM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeListByProduct_xtest    Script Date: 3/15/2016 10:50:20 AM ******/
CREATE PROCEDURE [dbo].[OIC_LicenseeListByProduct_xtest] 
    @ProductId			TINYINT
   ,@UserId				INT
AS
/*
    Created by: Kathy
    Date: 20150825
    Task: Licensee list belong to product [Redmine:#29610]
    DB: DBOIC.bodb_OIC
    
    Revisions:
		- 20160225@Percy: change sitename dropdown [Redmine: #52858]
    
    Param's Explanation:
		
*/
BEGIN
    SET NOCOUNT ON
    
    SELECT	LicenseeId, LicenseeName, LicenseeTypeId, LicenseeTypeName
    FROM	dbo.f_LicenseeBelongToProduct_xtest (@ProductId, @UserId)
   
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeListByType]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeListByType    Script Date: 17/09/2015 3:30:59 PM ******/
CREATE PROCEDURE [dbo].[OIC_LicenseeListByType]
	@UserId INT
AS
/*
	Created by: Kathy
	Date: 20150825
	Task: get all licensee belong to user [Redmine:#40305]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	Param's Explanation:
	
	*
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT	LicenseeTypeId
			,LicenseeTypeName
			,LicenseeId
			,LicenseeName
	FROM	dbo.f_LicenseeBelongToLicenseeType (@UserId)
	WHERE	LicenseeId IS NOT NULL
	ORDER BY LicenseeTypeId
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeListByUserSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeListByUserSel    Script Date: 17/09/2015 3:30:59 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeListByUserSel    Script Date: 15/05/2015 10:19:13 AM ******/

/****** Object:  Stored Procedure dbo.OIC_LicenseeListByUserSel    Script Date: 09/02/2015 3:30:04 PM ******/
CREATE PROCEDURE [dbo].[OIC_LicenseeListByUserSel]
    @UserId				INT
    ,@LicenseeType		TINYINT			= 0	
    ,@LicenseeName		NVARCHAR(50)		= NULL
    ,@Top				INT				= 10
AS
/*
    Created by: Kathy
    Date: 2015-02-04
    Task: Licensee list belong to Licensee Type of user login [Redmine:#29610]
    DB: DBOIC.bodb_OIC
    
    Revisions:
    
    Param's Explanation:
		@LicenseeType: 0 - All type of licensee
		@LicenseeName: '%' - All licensee
		@Top		 : 0 - All result

*/
BEGIN
    SET NOCOUNT ON
    
    IF @Top = 0
    BEGIN
		SELECT	l.LicenseeId
				,l.LicenseeName
		FROM dbo.Licensee l WITH(NOLOCK)
		WHERE l.LicenseeName LIKE ISNULL(@LicenseeName,'%') + '%'
		AND l.LicenseeTypeId IN (SELECT		LicenseeTypeId 
									FROM dbo.UserLicenseeType WITH(NOLOCK) 
									WHERE	UserId = @UserId
										AND (l.LicenseeTypeId = @LicenseeType OR @LicenseeType = 0)
								)
		ORDER BY l.LicenseeName 
    END
    ELSE
    BEGIN
		SELECT TOP(@Top) l.LicenseeId
				,l.LicenseeName
		FROM dbo.Licensee l WITH(NOLOCK)
		WHERE l.LicenseeName LIKE ISNULL(@LicenseeName,'%') + '%'
			AND l.LicenseeTypeId IN (SELECT LicenseeTypeId 
										FROM dbo.UserLicenseeType WITH(NOLOCK) 
										WHERE UserId = @UserId
											AND (l.LicenseeTypeId = @LicenseeType OR @LicenseeType = 0)
									)
		ORDER BY l.LicenseeName 
	END
                    
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeListSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeListSel    Script Date: 9/11/2017 11:37:17 PM ******/
CREATE PROCEDURE [dbo].[OIC_LicenseeListSel] 
	@UserId				INT				
	,@SelectedLicenseeType VARCHAR(50)	= 'All'
	,@LicenseeName		NVARCHAR(50)	= '%'
	,@LicenseeStatusIds	VARCHAR(50)	= 'All'
	,@SelectedProduct	VARCHAR(500)	= 'All'
	,@SelectedCurrency  VARCHAR(100)	= 'All'
	,@AMUserId			INT				= 0			--All
	,@PMUserId			INT				= 0			--All
	,@ResellerType	INT 			= -1		--All
	
	,@PageSize			INT = 10
	,@PageIndex			INT	= 0 
	,@TotalRecords		INT = 0 OUTPUT
	
AS

/*

	Created by: Kathy
	Date: 20150424
	Task: Client list [Redmine:#29609]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160628@Percy: Add Currency filter, return Currency column [RedmineID: #58982]
		- 20160805@Percy: Modify Currency filter for case no currency of Client [RedmineID: #62044]
		- 20161214@Percy: Change dropdown TOL filter multiple choices [RedmineID: #68774]
		- 20170828@Scofield: Add Reseller, Update LicenseeStatusIds [#82144]

	Param's Explanation:
		
	* @SelectedProduct: multiple selection dropdown(select 'All' or (1 or many product))(Product offered to the client)
	* @SelectedCurrency: multiple selection dropdown(select 'All' or (1 or many currency))(Currency offered to the client)
	* @LicenseeTypeIds: dropdown (select 0(All) or 1 licenseeTypeId)
	* @LicenseeStatusId: dropdown (select 0(All) or 1 licenseeStatusId)
	* @AMUser: dropdown(select 0(All) or 1 AMUser)
	* @PMUser: dropdown(select 0(All) or 1 PMUser)
	* @PageIndex: 0 - the first page

*/

BEGIN

	SET NOCOUNT ON
	
	DECLARE @RowCount	INT	
			,@RowStart	INT
			,@RowEnd	INT		
	
	SELECT @PageIndex	= @PageIndex ,
			@RowStart	= @PageSize * @PageIndex + 1
			,@RowEnd	= @RowStart + @PageSize - 1	
	
	DECLARE @tblProduct			TABLE (ProductId INT)
	DECLARE @tblLicenseeType	TABLE (LicenseeTypeId TINYINT)
	DECLARE @tblLicenseeProduct TABLE (LicenseeId INT)
	DECLARE @tblLicenseeCurrency TABLE (LicenseeId INT, currency VARCHAR(100))
	CREATE TABLE #tblResult	(
			RowNumber				INT
			,LicenseeId				INT
			,LicenseeName			NVARCHAR(50)
			,LicenseeStatusId		INT
			,LicenseeStatusName		VARCHAR(30)
			,LicenseeTypeId			TINYINT
			,LicenseeTypeName		VARCHAR(30)
			,SoftLaunch				DATETIME
			,FullLaunch				DATETIME
			,AccountManager			NVARCHAR(50)
			,ProjectManager			NVARCHAR(50)
			,MainContactId			INT
			,MainContactName		NVARCHAR(50)
			,currency				VARCHAR(400)
			,IsReseller				BIT
	)				
							
	INSERT INTO @tblProduct(ProductId)
	SELECT  p.ProductId
	FROM	dbo.Product p WITH(NOLOCK)
	WHERE	(@SelectedProduct = 'All' 
				OR p.ProductId IN (SELECT val FROM dbo.strSplit(@SelectedProduct,',')) 
			)
	
	IF @SelectedLicenseeType = 'All'
	BEGIN
		INSERT INTO @tblLicenseeType (LicenseeTypeId)
		SELECT	LicenseeTypeId
		FROM	dbo.UserLicenseeType WITH(NOLOCK)
		WHERE	UserId = @UserId
	END
	ELSE
	BEGIN
		INSERT INTO @tblLicenseeType (LicenseeTypeId)
		SELECT CONVERT(TINYINT, val) FROM dbo.strSplit(@SelectedLicenseeType, ',')

		DELETE lt
		FROM @tblLicenseeType lt
			LEFT JOIN dbo.UserLicenseeType ult WITH(NOLOCK) ON lt.LicenseeTypeId = ult.LicenseeTypeId AND ult.UserId = @UserId
		WHERE ult.LicenseeTypeId IS NULL
	END
				
	INSERT INTO @tblLicenseeProduct(LicenseeId)
	SELECT	lp.LicenseeId
	FROM	@tblProduct p 
		INNER JOIN dbo.LicenseeProduct lp WITH(NOLOCK) 
			ON	p.ProductId = lp.ProductId
		INNER JOIN dbo.Licensee l WITH (NOLOCK) 
			ON	l.LicenseeId = lp.LicenseeId
	GROUP BY  lp.LicenseeId
	HAVING COUNT(DISTINCT lp.ProductId) = CASE WHEN @SelectedProduct = 'All' THEN COUNT(DISTINCT lp.ProductId)
											   ELSE (SELECT COUNT(1) FROM @tblProduct)
										  END					
	;WITH CTE_Licensee (LicenseeId) AS
	(
		SELECT DISTINCT LicenseeId
		FROM dbo.LicenseeCurrency WITH(NOLOCK)
		WHERE
			@SelectedCurrency = 'All'
			OR CurrencyId IN (SELECT CONVERT(INT, val) FROM dbo.strSplit(@SelectedCurrency, ','))
	)
	,CTE_LicenseeCurrency (LicenseeId, currency) AS
	(
		SELECT DISTINCT lc.LicenseeId, e.code
		FROM
			dbo.LicenseeCurrency lc WITH(NOLOCK)
			INNER JOIN CTE_Licensee l ON lc.LicenseeId = l.LicenseeId
			LEFT JOIN bodb02.dbo.Exchange e WITH(NOLOCK) ON lc.CurrencyId = e.exchangeid
		WHERE
			@SelectedCurrency = 'All'
			OR e.exchangeid IS NOT NULL
	)
	INSERT INTO @tblLicenseeCurrency
	SELECT
		LicenseeId,
		(SELECT STUFF((SELECT ', ' + currency FROM CTE_LicenseeCurrency WHERE LicenseeId = lc.LicenseeId FOR XML PATH('')), 1, 1, ''))
	FROM CTE_LicenseeCurrency lc
	GROUP BY LicenseeId
				
	INSERT INTO #tblResult
	(
			RowNumber
			,LicenseeId
			,LicenseeName
			,LicenseeStatusId
			,LicenseeStatusName
			,LicenseeTypeId
			,LicenseeTypeName
			,SoftLaunch
			,FullLaunch
			,AccountManager
			,MainContactId
			,MainContactName
			,currency		
			,IsReseller
	)	
		 
	SELECT	ROW_NUMBER() OVER(ORDER BY LicenseeName) AS RowNumber
			,l.LicenseeId
			,l.LicenseeName
			,ls.LicenseeStatusId
			,ls.LicenseeStatusName
			,lt.LicenseeTypeId
			,lt.LicenseeTypeName
			,l.SoftLaunch
			,l.FullLaunch
			,u.DisplayName as AccountManager
			,c.ContactID
			,c.ContactName
			,lc.currency
			,l.IsReseller
	FROM	dbo.Licensee l WITH(NOLOCK)
		INNER JOIN dbo.LicenseeType lt WITH(NOLOCK)
			ON	lt.LicenseeTypeId = l.LicenseeTypeId
		INNER JOIN dbo.LicenseeStatus ls WITH(NOLOCK)
			ON	ls.LicenseeStatusId = l.LicenseeStatusId
		LEFT JOIN dbo.Contact c WITH(NOLOCK) 
			ON	c.LicenseeID = l.LicenseeId 
				AND c.IsMain = 1
		INNER JOIN (
			SELECT	ui.UserId
					,ui.DisplayName
					,ul.LicenseeId 
			FROM dbo.UserInfo ui WITH(NOLOCK)
				INNER JOIN UserLicensee ul WITH(NOLOCK)
					ON	ui.UserId = ul.UserId 
						AND ui.PositionId = 6 --AM 
						AND (@AMUserId = 0 OR ui.UserId = @AMUserId)
		) u 
			ON	u.LicenseeId = l.LicenseeId
		INNER JOIN @tblLicenseeCurrency lc
			ON l.LicenseeId = lc.LicenseeId
	WHERE	l.LicenseeName LIKE ISNULL(@LicenseeName,'%') + '%'
			AND l.LicenseeTypeId IN (SELECT LicenseeTypeId FROM @tblLicenseeType)
			AND (@LicenseeStatusIds = 'All' OR ls.LicenseeStatusId IN (SELECT val FROM dbo.strSplit(@LicenseeStatusIds,','))) 				
			AND (
					(@SelectedProduct <> 'All' 
						AND EXISTS (SELECT t.LicenseeId FROM @tblLicenseeProduct t
										WHERE t.LicenseeId = l.LicenseeId)
					) 
					OR (@SelectedProduct = 'All')
				)
			
	
			AND EXISTS (SELECT	LicenseeId 
						FROM	dbo.UserLicensee ulp WITH(NOLOCK)
							INNER JOIN dbo.UserInfo uip WITH(NOLOCK)
								ON	ulp.UserId = uip.UserId
									AND uip.PositionId = 5 -- AM
						WHERE	(uip.UserId = @PMUserId OR @PMUserId = 0) 
								AND l.LicenseeId = LicenseeID)
			AND (@ResellerType = -1 OR l.IsReseller = @ResellerType)
	
	UPDATE	t 
		SET ProjectManager = ui.DisplayName
	FROM	#tblResult t 
		INNER JOIN UserLicensee ul WITH(NOLOCK)
			ON	ul.LicenseeId = t.LicenseeId
		INNER JOIN dbo.UserInfo ui WITH(NOLOCK)
			ON	ui.UserId = ul.UserId 
				AND ui.PositionId = 5 -- PM								

	IF @TotalRecords = 0
	BEGIN
		SELECT @TotalRecords = COUNT(1)
		FROM #tblResult
	END		

	SELECT	t.LicenseeId
			,t.LicenseeName
			,t.LicenseeStatusName
			,t.LicenseeTypeId
			,t.LicenseeTypeName
			,t.FullLaunch
			,t.SoftLaunch
			,t.AccountManager
			,t.ProjectManager
			,t.MainContactId
			,t.MainContactName
			,t.currency
			,t.IsReseller
	FROM #tblResult t
	WHERE t.RowNumber BETWEEN @RowStart AND @RowEnd

	DROP TABLE #tblResult
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeListSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OIC_LicenseeListSel_xtest] 
	@UserId				INT				
	,@SelectedLicenseeType VARCHAR(50)	= 'All'
	,@LicenseeName		NVARCHAR(50)	= '%'
	,@LicenseeStatusIds	VARCHAR(50)	= 'All'
	,@SelectedProduct	VARCHAR(500)	= 'All'
	,@SelectedCurrency  VARCHAR(100)	= 'All'
	,@AMUserId			INT				= 0			--All
	,@PMUserId			INT				= 0			--All
	,@ResellerType	INT 			= -1		--All
	
	,@PageSize			INT = 10
	,@PageIndex			INT	= 0 
	,@TotalRecords		INT = 0 OUTPUT
	
AS

/*

	Created by: Kathy
	Date: 20150424
	Task: Client list [Redmine:#29609]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160628@Percy: Add Currency filter, return Currency column [RedmineID: #58982]
		- 20160805@Percy: Modify Currency filter for case no currency of Client [RedmineID: #62044]
		- 20161214@Percy: Change dropdown TOL filter multiple choices [RedmineID: #68774]
		- 20170828@Scofield: Add Reseller, Update LicenseeStatusIds [#82144]

	Param's Explanation:
		
	* @SelectedProduct: multiple selection dropdown(select 'All' or (1 or many product))(Product offered to the client)
	* @SelectedCurrency: multiple selection dropdown(select 'All' or (1 or many currency))(Currency offered to the client)
	* @LicenseeTypeIds: dropdown (select 0(All) or 1 licenseeTypeId)
	* @LicenseeStatusId: dropdown (select 0(All) or 1 licenseeStatusId)
	* @AMUser: dropdown(select 0(All) or 1 AMUser)
	* @PMUser: dropdown(select 0(All) or 1 PMUser)
	* @PageIndex: 0 - the first page

*/

BEGIN

	SET NOCOUNT ON
	
	DECLARE @RowCount	INT	
			,@RowStart	INT
			,@RowEnd	INT		
	
	SELECT @PageIndex	= @PageIndex ,
			@RowStart	= @PageSize * @PageIndex + 1
			,@RowEnd	= @RowStart + @PageSize - 1	
	
	DECLARE @tblProduct			TABLE (ProductId INT)
	DECLARE @tblLicenseeType	TABLE (LicenseeTypeId TINYINT)
	DECLARE @tblLicenseeProduct TABLE (LicenseeId INT)
	DECLARE @tblLicenseeCurrency TABLE (LicenseeId INT, currency VARCHAR(100))
	CREATE TABLE #tblResult	(
			RowNumber				INT
			,LicenseeId				INT
			,LicenseeName			NVARCHAR(50)
			,LicenseeStatusId		INT
			,LicenseeStatusName		VARCHAR(30)
			,LicenseeTypeId			TINYINT
			,LicenseeTypeName		VARCHAR(30)
			,SoftLaunch				DATETIME
			,FullLaunch				DATETIME
			,AccountManager			NVARCHAR(50)
			,ProjectManager			NVARCHAR(50)
			,MainContactId			INT
			,MainContactName		NVARCHAR(50)
			,currency				VARCHAR(400)
			,IsReseller				BIT
	)				
							
	INSERT INTO @tblProduct(ProductId)
	SELECT  p.ProductId
	FROM	dbo.Product p WITH(NOLOCK)
	WHERE	(@SelectedProduct = 'All' 
				OR p.ProductId IN (SELECT val FROM dbo.strSplit(@SelectedProduct,',')) 
			)
	
	IF @SelectedLicenseeType = 'All'
	BEGIN
		INSERT INTO @tblLicenseeType (LicenseeTypeId)
		SELECT	LicenseeTypeId
		FROM	dbo.UserLicenseeType WITH(NOLOCK)
		WHERE	UserId = @UserId
	END
	ELSE
	BEGIN
		INSERT INTO @tblLicenseeType (LicenseeTypeId)
		SELECT CONVERT(TINYINT, val) FROM dbo.strSplit(@SelectedLicenseeType, ',')

		DELETE lt
		FROM @tblLicenseeType lt
			LEFT JOIN dbo.UserLicenseeType ult WITH(NOLOCK) ON lt.LicenseeTypeId = ult.LicenseeTypeId AND ult.UserId = @UserId
		WHERE ult.LicenseeTypeId IS NULL
	END
				
	INSERT INTO @tblLicenseeProduct(LicenseeId)
	SELECT	lp.LicenseeId
	FROM	@tblProduct p 
		INNER JOIN dbo.LicenseeProduct lp WITH(NOLOCK) 
			ON	p.ProductId = lp.ProductId
		INNER JOIN dbo.Licensee l WITH (NOLOCK) 
			ON	l.LicenseeId = lp.LicenseeId
	GROUP BY  lp.LicenseeId
	HAVING COUNT(DISTINCT lp.ProductId) = CASE WHEN @SelectedProduct = 'All' THEN COUNT(DISTINCT lp.ProductId)
											   ELSE (SELECT COUNT(1) FROM @tblProduct)
										  END					
	;WITH CTE_Licensee (LicenseeId) AS
	(
		SELECT DISTINCT LicenseeId
		FROM dbo.LicenseeCurrency WITH(NOLOCK)
		WHERE
			@SelectedCurrency = 'All'
			OR CurrencyId IN (SELECT CONVERT(INT, val) FROM dbo.strSplit(@SelectedCurrency, ','))
	)
	,CTE_LicenseeCurrency (LicenseeId, currency) AS
	(
		SELECT DISTINCT lc.LicenseeId, e.code
		FROM
			dbo.LicenseeCurrency lc WITH(NOLOCK)
			INNER JOIN CTE_Licensee l ON lc.LicenseeId = l.LicenseeId
			LEFT JOIN bodb02.dbo.Exchange e WITH(NOLOCK) ON lc.CurrencyId = e.exchangeid
		WHERE
			@SelectedCurrency = 'All'
			OR e.exchangeid IS NOT NULL
	)
	INSERT INTO @tblLicenseeCurrency
	SELECT
		LicenseeId,
		(SELECT STUFF((SELECT ', ' + currency FROM CTE_LicenseeCurrency WHERE LicenseeId = lc.LicenseeId FOR XML PATH('')), 1, 1, ''))
	FROM CTE_LicenseeCurrency lc
	GROUP BY LicenseeId
				
	INSERT INTO #tblResult
	(
			RowNumber
			,LicenseeId
			,LicenseeName
			,LicenseeStatusId
			,LicenseeStatusName
			,LicenseeTypeId
			,LicenseeTypeName
			,SoftLaunch
			,FullLaunch
			,AccountManager
			,MainContactId
			,MainContactName
			,currency		
			,IsReseller
	)	
		 
	SELECT	ROW_NUMBER() OVER(ORDER BY LicenseeName) AS RowNumber
			,l.LicenseeId
			,l.LicenseeName
			,ls.LicenseeStatusId
			,ls.LicenseeStatusName
			,lt.LicenseeTypeId
			,lt.LicenseeTypeName
			,l.SoftLaunch
			,l.FullLaunch
			,u.DisplayName as AccountManager
			,c.ContactID
			,c.ContactName
			,lc.currency
			,l.IsReseller
	FROM	dbo.Licensee l WITH(NOLOCK)
		INNER JOIN dbo.LicenseeType lt WITH(NOLOCK)
			ON	lt.LicenseeTypeId = l.LicenseeTypeId
		INNER JOIN dbo.LicenseeStatus ls WITH(NOLOCK)
			ON	ls.LicenseeStatusId = l.LicenseeStatusId
		LEFT JOIN dbo.Contact c WITH(NOLOCK) 
			ON	c.LicenseeID = l.LicenseeId 
				AND c.IsMain = 1
		INNER JOIN (
			SELECT	ui.UserId
					,ui.DisplayName
					,ul.LicenseeId 
			FROM dbo.UserInfo ui WITH(NOLOCK)
				INNER JOIN UserLicensee ul WITH(NOLOCK)
					ON	ui.UserId = ul.UserId 
						AND ui.PositionId = 6 --AM 
						AND (@AMUserId = 0 OR ui.UserId = @AMUserId)
		) u 
			ON	u.LicenseeId = l.LicenseeId
		INNER JOIN @tblLicenseeCurrency lc
			ON l.LicenseeId = lc.LicenseeId
	WHERE	l.LicenseeName LIKE ISNULL(@LicenseeName,'%') + '%'
			AND l.LicenseeTypeId IN (SELECT LicenseeTypeId FROM @tblLicenseeType)
			AND (@LicenseeStatusIds = 'All' OR ls.LicenseeStatusId IN (SELECT val FROM dbo.strSplit(@LicenseeStatusIds,','))) 				
			AND (
					(@SelectedProduct <> 'All' 
						AND EXISTS (SELECT t.LicenseeId FROM @tblLicenseeProduct t
										WHERE t.LicenseeId = l.LicenseeId)
					) 
					OR (@SelectedProduct = 'All')
				)
			
	
			AND EXISTS (SELECT	LicenseeId 
						FROM	dbo.UserLicensee ulp WITH(NOLOCK)
							INNER JOIN dbo.UserInfo uip WITH(NOLOCK)
								ON	ulp.UserId = uip.UserId
									AND uip.PositionId = 5 -- AM
						WHERE	(uip.UserId = @PMUserId OR @PMUserId = 0) 
								AND l.LicenseeId = LicenseeID)
			AND (@ResellerType = -1 OR l.IsReseller = @ResellerType)
	
	UPDATE	t 
		SET ProjectManager = ui.DisplayName
	FROM	#tblResult t 
		INNER JOIN UserLicensee ul WITH(NOLOCK)
			ON	ul.LicenseeId = t.LicenseeId
		INNER JOIN dbo.UserInfo ui WITH(NOLOCK)
			ON	ui.UserId = ul.UserId 
				AND ui.PositionId = 5 -- PM								

	IF @TotalRecords = 0
	BEGIN
		SELECT @TotalRecords = COUNT(1)
		FROM #tblResult
	END		

	SELECT	t.LicenseeId
			,t.LicenseeName
			,t.LicenseeStatusName
			,t.LicenseeTypeId
			,t.LicenseeTypeName
			,t.FullLaunch
			,t.SoftLaunch
			,t.AccountManager
			,t.ProjectManager
			,t.MainContactId
			,t.MainContactName
			,t.currency
			,t.IsReseller
	FROM #tblResult t
	WHERE t.RowNumber BETWEEN @RowStart AND @RowEnd

	DROP TABLE #tblResult
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeMainContactInfoSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeMainContactInfoSel    Script Date: 15/05/2015 10:19:13 AM ******/
CREATE PROCEDURE [dbo].[OIC_LicenseeMainContactInfoSel] --1
	@MainContactId INT
AS
/*
	Created by: Kathy
	Date: 2015-04-21
	Task: Get info main contact of licensee [Redmine:#29609]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	
	
 */
BEGIN

	SET NOCOUNT ON
	
	SELECT	c.ContactName
			,c.ContactPosition
			,c.ContactEmail
			,c.ContactSkype
			,c.ContactPhoneNumber
	FROM	dbo.Contact c WITH(NOLOCK)
		INNER JOIN dbo.Licensee l WITH(NOLOCK) 
			ON	l.LicenseeId = c.LicenseeID 
	WHERE	c.ContactID = @MainContactId
			AND c.IsMain = 1	
	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeNameChecking]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeNameChecking    Script Date: 15/05/2015 10:19:13 AM ******/
CREATE PROCEDURE [dbo].[OIC_LicenseeNameChecking]
	@SiteName	NVARCHAR(50)
	,@LicenseeId INT			= 0
	,@Language	VARCHAR(10)		= 'E'
	,@ErrCode	INT				= 0			OUTPUT
	,@ErrMsg	VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2015-01-15
	Task: Checking licensee name [Redmine:#27752]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	Param's Explanation:
	* @ErrCode:
		= 0: 
		> 0: Specific Error.
  
	* @ErrMsg: Error description.
	
 */
BEGIN
	SET NOCOUNT ON
	
	IF @LicenseeId = 0 -- New Licensee
	BEGIN
		IF EXISTS(SELECT TOP 1 1 FROM dbo.Licensee WITH(NOLOCK) WHERE LicenseeName = @SiteName)
		BEGIN
			SELECT @ErrCode = 99
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](4,@Language) -- The site name is already used. Please try another name.
			RETURN
		END
	END
	ELSE
	BEGIN
		IF EXISTS(SELECT TOP 1 1 FROM dbo.Licensee WITH(NOLOCK) WHERE LicenseeName = @SiteName AND LicenseeId <> @LicenseeId)
		BEGIN
			SELECT @ErrCode = 99
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](4,@Language) -- The site name is already used. Please try another name.
			RETURN
		END
	END
	
	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeProductByLicenseeSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeProductByLicenseeSel    Script Date: 6/20/2016 11:20:51 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeProductByLicenseeSel    Script Date: 6/7/2016 4:13:26 PM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeProductByLicenseeSel]
	@LicenseeId				INT
AS
/*
	Created by: Kathy
	Date: 2015-04-03
	Task: select products of client [Redmine:#29613]
	DB: DBOIC/BODB_OIC 
	
	Revisions:
		- 20160513@Percy: return field TerminationDate [RedmineID: #56935]
	
	Param's Explanation:
		
		
 */
BEGIN
	SET NOCOUNT ON
	
	SELECT	p.ProductId
			,p.ProductName
			,CASE WHEN lp.ProductId IS NULL THEN 0 ELSE 1 END Selected
			,lp.LaunchDate
			,lp.TerminationDate
	FROM dbo.Product p WITH(NOLOCK)
		LEFT JOIN dbo.LicenseeProduct lp 
			ON	p.ProductId = lp.ProductId 
				AND lp.LicenseeId = @LicenseeId
	ORDER BY p.[Order]
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeProductByLicenseeSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeProductByLicenseeSel_xtest    Script Date: 6/7/2016 4:13:26 PM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeProductByLicenseeSel_xtest]
	@LicenseeId				INT
AS
/*
	Created by: Kathy
	Date: 2015-04-03
	Task: select products of client [Redmine:#29613]
	DB: DBOIC/BODB_OIC 
	
	Revisions:
		- 20160513@Percy: return field TerminationDate [RedmineID: #56935]
	
	Param's Explanation:
		
		
 */
BEGIN
	SET NOCOUNT ON
	
	SELECT	p.ProductId
			,p.ProductName
			,CASE WHEN lp.ProductId IS NULL THEN 0 ELSE 1 END Selected
			,lp.LaunchDate
			,lp.TerminationDate
	FROM dbo.Product p WITH(NOLOCK)
		LEFT JOIN dbo.LicenseeProduct lp 
			ON	p.ProductId = lp.ProductId 
				AND lp.LicenseeId = @LicenseeId
	ORDER BY p.[Order]
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeProductByLicenseeUpd]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeProductByLicenseeUpd    Script Date: 5/3/2017 10:41:09 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeProductByLicenseeUpd    Script Date: 4/24/2017 10:21:28 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeProductByLicenseeUpd]
	@LicenseeId			INT
	,@SelectedProduct	XML
	,@UserId			INT
	,@Language			VARCHAR(10)		= 'E'
	,@IP				VARCHAR(50)		= NULL
	,@ErrCode			INT				= 0			OUTPUT
	,@ErrMsg			VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2015-04-03
	Task: Edit products of client [Redmine:#29613]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160513@Percy: add field terminationdate [RedmineID: #56935]
	
	Param's Explanation:
	- @SelectedProduct: list of product			
				<root>
					<row ProductId="1" launchdate="2014-12-19" terminationdate="2016-05-13"/>
					<row ProductId="3" launchdate="2014-12-19"/>
				</root>
				
	- Log:	
			<root><xml path="r" />
				<row item="LicenseeId" alias="lid" />
				<row item="LicenseeName" alias="ln" />				
				<row item="ProductId" alias="pid" />
				<row item="ProductName" alias="pn" />
				<row item="LaunchDate" alias="lpld" />		
				<row item="TerminationDate" alias="lptd" />						
			</root>
*/
BEGIN
	SET NOCOUNT ON

	-- For write log
	DECLARE @startRun	DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPOlddata	NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
		,@LicenseeName	NVARCHAR(50)

	SET @startRun = GETDATE()

	DECLARE @tblProductOffered TABLE (ProductId INT, LaunchDate DATETIME, TerminationDate DATETIME)

	SELECT	@LicenseeName = LicenseeName
	FROM dbo.Licensee WITH (NOLOCK)
	WHERE	LicenseeId = @LicenseeId

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](5, @Language) -- Licensee does not exist.
		RETURN
	END

	INSERT INTO @tblProductOffered (
			ProductId
			,LaunchDate
			,TerminationDate
	)
	SELECT	t.c.value('@ProductId', 'int') AS ProductId
			,t.c.value('@launchdate', 'datetime') AS LaunchDate
			,t.c.value('@terminationdate', 'datetime') AS TerminationDate
	FROM @SelectedProduct.nodes('root/row') t(c)

	IF @@ERROR <> 0
	BEGIN
		SELECT	@ErrCode = 102
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1001, @Language) -- Fail to edit client's products. Please try again.
		RETURN
	END

	-- get data before update/insert
	SET @xml = (
			SELECT	@LicenseeId AS '@lid'
					,@LicenseeName AS '@ln'
					,(
						SELECT	lp.ProductId AS '@pid'
								,p.ProductName AS '@pn'
								,p.[Order] AS '@pod'
								,lp.LaunchDate AS '@lld'
								,lp.TerminationDate AS '@ltd'
						FROM dbo.LicenseeProduct lp WITH (NOLOCK)
							INNER JOIN dbo.Product p WITH (NOLOCK) 
								ON	p.ProductId = lp.ProductId
						WHERE lp.LicenseeId = @LicenseeId
					FOR XML PATH('row'), ROOT('lp'), TYPE
					)
			FOR XML PATH('r'), TYPE
			)

	SELECT @logSPOldData = CONVERT(NVARCHAR(MAX), @xml)

	BEGIN TRY
		MERGE dbo.LicenseeProduct as lp
		USING (SELECT ProductId, LaunchDate, TerminationDate FROM @tblProductOffered) AS t
		ON	(lp.ProductId = t.ProductId
			AND lp.LicenseeId = @LicenseeId)
		WHEN MATCHED AND (lp.LaunchDate <> t.LaunchDate OR ISNULL(lp.TerminationDate, '') <> ISNULL(t.TerminationDate, '')) THEN UPDATE SET lp.LaunchDate = t.LaunchDate, lp.TerminationDate = t.TerminationDate
		WHEN NOT MATCHED BY TARGET THEN INSERT (LicenseeId, ProductId, LaunchDate, TerminationDate) VALUES(@LicenseeId, t.ProductId, t.LaunchDate, t.TerminationDate)
		WHEN NOT MATCHED BY SOURCE AND lp.LicenseeId = @LicenseeId THEN DELETE;
	END TRY

	BEGIN CATCH
		SELECT	@ErrCode = 103
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1001, @Language) + ERROR_MESSAGE() -- Fail to edit client's products. Please try again.
		RETURN
	END CATCH

	-- Write log
	SET @xml = (
			SELECT	@LicenseeId AS '@lid'
					,@LicenseeName AS '@ln'
					,(
						SELECT	lp.ProductId AS '@pid'
								,p.ProductName AS '@pn'
								,p.[Order] AS '@pod'
								,lp.LaunchDate AS '@lld'
								,lp.TerminationDate AS '@ltd'
						FROM dbo.LicenseeProduct lp WITH (NOLOCK)
							INNER JOIN dbo.Product p WITH (NOLOCK) 
								ON	p.ProductId = lp.ProductId
						WHERE	lp.ProductId IN (SELECT ProductId	FROM @tblProductOffered)
								AND lp.LicenseeId = @LicenseeId
						FOR XML PATH('row'),ROOT('lp'),TYPE
					)
			FOR XML PATH('r'),TYPE
			)

	SELECT @logSPData	= CONVERT(NVARCHAR(MAX), @xml)
		,@endRun		= GETDATE()
		,@duration		= DATEDIFF(MILLISECOND, @startRun, @endRun)
		,@procName		= OBJECT_NAME(@@PROCID)

		EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOlddata
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeProductByLicenseeUpd_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeProductByLicenseeUpd_xtest    Script Date: 4/24/2017 10:21:28 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeProductByLicenseeUpd_xtest]
	@LicenseeId			INT
	,@SelectedProduct	XML
	,@UserId			INT
	,@Language			VARCHAR(10)		= 'E'
	,@IP				VARCHAR(50)		= NULL
	,@ErrCode			INT				= 0			OUTPUT
	,@ErrMsg			VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 2015-04-03
	Task: Edit products of client [Redmine:#29613]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160513@Percy: add field terminationdate [RedmineID: #56935]
	
	Param's Explanation:
	- @SelectedProduct: list of product			
				<root>
					<row ProductId="1" launchdate="2014-12-19" terminationdate="2016-05-13"/>
					<row ProductId="3" launchdate="2014-12-19"/>
				</root>
				
	- Log:	
			<root><xml path="r" />
				<row item="LicenseeId" alias="lid" />
				<row item="LicenseeName" alias="ln" />				
				<row item="ProductId" alias="pid" />
				<row item="ProductName" alias="pn" />
				<row item="LaunchDate" alias="lpld" />		
				<row item="TerminationDate" alias="lptd" />						
			</root>
*/
BEGIN
	SET NOCOUNT ON

	-- For write log
	DECLARE @startRun	DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPOlddata	NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
		,@LicenseeName	NVARCHAR(50)

	SET @startRun = GETDATE()

	DECLARE @tblProductOffered TABLE (ProductId INT, LaunchDate DATETIME, TerminationDate DATETIME)

	SELECT	@LicenseeName = LicenseeName
	FROM dbo.Licensee WITH (NOLOCK)
	WHERE	LicenseeId = @LicenseeId

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](5, @Language) -- Licensee does not exist.
		RETURN
	END

	INSERT INTO @tblProductOffered (
			ProductId
			,LaunchDate
			,TerminationDate
	)
	SELECT	t.c.value('@ProductId', 'int') AS ProductId
			,t.c.value('@launchdate', 'datetime') AS LaunchDate
			,t.c.value('@terminationdate', 'datetime') AS TerminationDate
	FROM @SelectedProduct.nodes('root/row') t(c)

	IF @@ERROR <> 0
	BEGIN
		SELECT	@ErrCode = 102
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1001, @Language) -- Fail to edit client's products. Please try again.
		RETURN
	END

	-- get data before update/insert
	SET @xml = (
			SELECT	@LicenseeId AS '@lid'
					,@LicenseeName AS '@ln'
					,(
						SELECT	lp.ProductId AS '@pid'
								,p.ProductName AS '@pn'
								,p.[Order] AS '@pod'
								,lp.LaunchDate AS '@lld'
								,lp.TerminationDate AS '@ltd'
						FROM dbo.LicenseeProduct lp WITH (NOLOCK)
							INNER JOIN dbo.Product p WITH (NOLOCK) 
								ON	p.ProductId = lp.ProductId
						WHERE lp.LicenseeId = @LicenseeId
					FOR XML PATH('row'), ROOT('lp'), TYPE
					)
			FOR XML PATH('r'), TYPE
			)

	SELECT @logSPOldData = CONVERT(NVARCHAR(MAX), @xml)

	BEGIN TRY
		MERGE dbo.LicenseeProduct as lp
		USING (SELECT ProductId, LaunchDate, TerminationDate FROM @tblProductOffered) AS t
		ON	(lp.ProductId = t.ProductId
			AND lp.LicenseeId = @LicenseeId)
		WHEN MATCHED AND (lp.LaunchDate <> t.LaunchDate OR ISNULL(lp.TerminationDate, '') <> ISNULL(t.TerminationDate, '')) THEN UPDATE SET lp.LaunchDate = t.LaunchDate, lp.TerminationDate = t.TerminationDate
		WHEN NOT MATCHED BY TARGET THEN INSERT (LicenseeId, ProductId, LaunchDate, TerminationDate) VALUES(@LicenseeId, t.ProductId, t.LaunchDate, t.TerminationDate)
		WHEN NOT MATCHED BY SOURCE AND lp.LicenseeId = @LicenseeId THEN DELETE;
	END TRY

	BEGIN CATCH
		SELECT	@ErrCode = 103
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1001, @Language) + ERROR_MESSAGE() -- Fail to edit client's products. Please try again.
		RETURN
	END CATCH

	-- Write log
	SET @xml = (
			SELECT	@LicenseeId AS '@lid'
					,@LicenseeName AS '@ln'
					,(
						SELECT	lp.ProductId AS '@pid'
								,p.ProductName AS '@pn'
								,p.[Order] AS '@pod'
								,lp.LaunchDate AS '@lld'
								,lp.TerminationDate AS '@ltd'
						FROM dbo.LicenseeProduct lp WITH (NOLOCK)
							INNER JOIN dbo.Product p WITH (NOLOCK) 
								ON	p.ProductId = lp.ProductId
						WHERE	lp.ProductId IN (SELECT ProductId	FROM @tblProductOffered)
								AND lp.LicenseeId = @LicenseeId
						FOR XML PATH('row'),ROOT('lp'),TYPE
					)
			FOR XML PATH('r'),TYPE
			)

	SELECT @logSPData	= CONVERT(NVARCHAR(MAX), @xml)
		,@endRun		= GETDATE()
		,@duration		= DATEDIFF(MILLISECOND, @startRun, @endRun)
		,@procName		= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOlddata
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeProductByProductSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeProductByProductSel    Script Date: 6/20/2016 11:20:52 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeProductByProductSel    Script Date: 6/7/2016 4:13:26 PM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeProductByProductSel]
	@ProductId			TINYINT
	,@UserId			INT
AS
/*
	Created by: Kathy
	Date: 2015-04-03
	Task: Offer product to clients [Redmine:#29613]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160513@Percy: return field TerminationDate [RedmineID: #56935]
	
	Param's Explanation:
		
		
 */
BEGIN
	SET NOCOUNT ON
	
	SELECT	l.LicenseeId
			,l.LicenseeName
			,CASE WHEN lp.LicenseeId IS NULL THEN 0 ELSE 1 END AS Selected
			,lp.LaunchDate
			,lp.TerminationDate
	FROM dbo.Licensee l WITH(NOLOCK)
		LEFT JOIN dbo.LicenseeProduct lp WITH(NOLOCK) 
			ON	l.LicenseeId = lp.LicenseeId 
				AND lp.ProductId = @ProductId
	WHERE l.LicenseeTypeId IN (SELECT LicenseeTypeId FROM dbo.UserLicenseeType WITH(NOLOCK) WHERE UserId = @UserId)
	ORDER BY l.LicenseeName
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeProductByProductSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeProductByProductSel_xtest    Script Date: 6/7/2016 4:13:26 PM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeProductByProductSel_xtest]
	@ProductId			TINYINT
	,@UserId			INT
AS
/*
	Created by: Kathy
	Date: 2015-04-03
	Task: Offer product to clients [Redmine:#29613]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160513@Percy: return field TerminationDate [RedmineID: #56935]
	
	Param's Explanation:
		
		
 */
BEGIN
	SET NOCOUNT ON
	
	SELECT	l.LicenseeId
			,l.LicenseeName
			,CASE WHEN lp.LicenseeId IS NULL THEN 0 ELSE 1 END AS Selected
			,lp.LaunchDate
			,lp.TerminationDate
	FROM dbo.Licensee l WITH(NOLOCK)
		LEFT JOIN dbo.LicenseeProduct lp WITH(NOLOCK) 
			ON	l.LicenseeId = lp.LicenseeId 
				AND lp.ProductId = @ProductId
	WHERE l.LicenseeTypeId IN (SELECT LicenseeTypeId FROM dbo.UserLicenseeType WITH(NOLOCK) WHERE UserId = @UserId)
	ORDER BY l.LicenseeName
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeProductByProductUpd]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeProductByProductUpd    Script Date: 5/3/2017 10:41:09 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeProductByProductUpd    Script Date: 4/24/2017 10:21:28 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeProductByProductUpd]
    @ProductId           TINYINT
    ,@SelectedLicensee   XML				= NULL
    
    ,@UserId             INT
    ,@Language           VARCHAR(10)        = 'E'
    ,@IP                 VARCHAR(50)        = NULL
    ,@ErrCode            INT                = 0            OUTPUT
    ,@ErrMsg             VARCHAR(300)    = NULL        OUTPUT
AS
/*
    Created by: Kathy
    Date: 2015-04-03
    Task: Offer product to clients [Redmine:#29613]
    DB: DBOIC.bodb_OIC
    
    Revisions:
		- 20160513@Percy: add field terminationdate [RedmineID: #56935]
    
    Param's Explanation:
    - @SelectedLicensee: list of licensee                    
                <root>
                    <row LicenseeId="1" launchdate="2014-12-19" terminationdate="2016-05-13"/>
                    <row LicenseeId="3" launchdate="2014-12-19"/>
                </root>
    
    - Log:
        <root><xml path="r" />
            <row item="ProductId" alias="pid" />
            <row item="ProductName" alias="pn" />
            <row item="LicenseeId" alias="lid" />
            <row item="LicenseeName" alias="ln" />
            <row item="LaunchDate" alias="lpld" />
			<row item="TerminationDate" alias="lptd" />            
        </root>    
        
 */
BEGIN
    SET NOCOUNT ON
    
    
    -- For write log
    DECLARE 
        @startRun       DATETIME
        ,@endRun        DATETIME
        ,@duration      INT
        ,@logSPData     NVARCHAR(MAX)
        ,@logSPOlddata  NVARCHAR(MAX)    
        ,@xml           XML
        ,@procName      VARCHAR(200)
        ,@ProductName   VARCHAR(50)

		,@tempStartRun	DATETIME
		,@tempEndRun	DATETIME
    
    SET @startRun = GETDATE()
    
    DECLARE @tblLicenseeoffered TABLE (LicenseeId INT, LaunchDate DATETIME, TerminationDate DATETIME, IsDelete BIT DEFAULT 0)
	DECLARE @tblLicenseebefore TABLE (LicenseeId INT, LaunchDate DATETIME, TerminationDate DATETIME, IsDelete BIT DEFAULT 0)
    
    SELECT @ProductName = ProductName 
    FROM dbo.Product WITH(NOLOCK) 
    WHERE ProductId = @ProductId
    
    IF @@ROWCOUNT = 0
    BEGIN
        SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30000, @Language) -- Product does not exist.
        RETURN
    END
    
    INSERT INTO @tblLicenseeoffered (LicenseeId, LaunchDate, TerminationDate)
    SELECT	t.c.value('@LicenseeId','int') AS LicenseeId
			,t.c.value('@launchdate', 'datetime') AS LaunchDate
			,t.c.value('@terminationdate', 'datetime') AS TerminationDate
    FROM @SelectedLicensee.nodes('root/row') t(c)

	INSERT INTO @tblLicenseebefore (LicenseeId, LaunchDate, TerminationDate)
	SELECT	l.LicenseeId, lp.LaunchDate, lp.TerminationDate
	FROM dbo.Licensee AS l WITH (NOLOCK)
		INNER JOIN dbo.LicenseeProduct lp WITH(NOLOCK) ON l.LicenseeId = lp.LicenseeId 
	WHERE lp.ProductId = @ProductId
    
    IF @@ERROR <> 0
    BEGIN
        SELECT	@ErrCode = 102
                ,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1000,@Language) -- Fail to edit product's clients. Please try again.
        RETURN
    END
    
    -- get data before update/insert
    SET @xml = (SELECT	@ProductId                AS '@pid'
						,@ProductName                AS '@pn'
						,(SELECT	l.LicenseeId        AS '@lid'
									,l.LicenseeName        AS '@ln'
									,lp.LaunchDate        AS '@lpld'
									,lp.TerminationDate        AS '@lptd'
							FROM dbo.Licensee AS l WITH (NOLOCK)
								INNER JOIN dbo.LicenseeProduct lp WITH(NOLOCK) 
									ON	l.LicenseeId = lp.LicenseeId 
							WHERE lp.ProductId = @ProductId
							FOR XML PATH('row'), TYPE, ROOT('lp')
						)
				FOR XML PATH('r')
				)        
    SELECT @logSPOldData = CONVERT(NVARCHAR(MAX),@xml)
    
    BEGIN TRY
		MERGE dbo.LicenseeProduct AS lp
		USING (SELECT LicenseeId, LaunchDate, TerminationDate FROM @tblLicenseeoffered) AS t
			ON	(lp.LicenseeId = t.LicenseeId AND lp.ProductId = @ProductId)
		WHEN MATCHED AND (lp.LaunchDate <> t.LaunchDate OR ISNULL(lp.TerminationDate, '') <> ISNULL(t.TerminationDate, '')) THEN UPDATE SET lp.LaunchDate = t.LaunchDate, lp.TerminationDate = t.TerminationDate
		WHEN NOT MATCHED BY TARGET THEN INSERT (LicenseeId, ProductId, LaunchDate, TerminationDate) VALUES (t.LicenseeId, @ProductId, t.LaunchDate, t.TerminationDate);
		
		DELETE	dbo.LicenseeProduct WITH(ROWLOCK, UPDLOCK)
		WHERE	ProductId = @ProductId
				AND LicenseeId NOT IN (SELECT LicenseeId FROM @tblLicenseeoffered)
				
    END TRY
    BEGIN CATCH
        SELECT	@ErrCode = 103
                ,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1000, @Language) + ERROR_MESSAGE() -- Fail to edit product's clients. Please try again.
        RETURN
    END CATCH        

    -- Write log
    SET @xml = (SELECT	@ProductId						AS '@pid'
                        ,@ProductName					AS '@pn'
                        ,(SELECT l.LicenseeId			AS '@lid'
                                ,l.LicenseeName			AS '@ln'
                                ,lp.LaunchDate			AS '@lpld'
								,lp.TerminationDate			AS '@lptd'
                            FROM dbo.Licensee AS l WITH (NOLOCK)
								INNER JOIN dbo.LicenseeProduct lp WITH(NOLOCK) 
									ON	l.LicenseeId = lp.LicenseeId 
                            WHERE	l.LicenseeId IN (SELECT LicenseeId FROM @tblLicenseeoffered)
									AND lp.ProductId = @ProductId
                            FOR XML PATH('row'), TYPE, ROOT('lp')
                        )
                FOR XML PATH('r')
                )        
        
    SELECT @logSPData = CONVERT(NVARCHAR(MAX),@xml)
        ,@endRun    = GETDATE()  
        ,@duration    = DATEDIFF(MILLISECOND, @startRun, @endRun)   
        ,@procName    = OBJECT_NAME(@@PROCID)
    
        EXEC dbo.OIC_LogRunSpIns
		@UserId         = @UserId
		,@SPName        = @procName
		,@Language      = @Language
		,@IP            = @IP
		,@Data          = @logSPData
		,@OldData       = @logSPOlddata
		,@Duration      = @Duration

	DECLARE @Licensee TABLE (LicenseeId INT, LaunchDate DATETIME, TerminationDate DATETIME)
	DECLARE @LicenseeId INT

	SELECT  @procName = SPName, @tempEndRun = GETDATE() FROM dbo.LogAction WITH(NOLOCK) WHERE LogActionId = 201 -- write log for client

	UPDATE b
	SET b.IsDelete = 1
	FROM @tblLicenseebefore b
		INNER JOIN @tblLicenseeoffered a ON b.LicenseeId = a.LicenseeId
	WHERE ISNULL(b.LaunchDate, CONVERT(DATETIME, '19700101')) = ISNULL(a.LaunchDate, CONVERT(DATETIME, '19700101'))
		AND ISNULL(b.TerminationDate, CONVERT(DATETIME, '19700101')) = ISNULL(a.TerminationDate, CONVERT(DATETIME, '19700101'))

	UPDATE a
	SET a.IsDelete = 1
	FROM @tblLicenseebefore b
		INNER JOIN @tblLicenseeoffered a ON b.LicenseeId = a.LicenseeId
	WHERE ISNULL(b.LaunchDate, CONVERT(DATETIME, '19700101')) = ISNULL(a.LaunchDate, CONVERT(DATETIME, '19700101'))
		AND ISNULL(b.TerminationDate, CONVERT(DATETIME, '19700101')) = ISNULL(a.TerminationDate, CONVERT(DATETIME, '19700101'))

	DELETE @tblLicenseebefore WHERE IsDelete = 1
	DELETE @tblLicenseeoffered WHERE IsDelete = 1

	WHILE 1=1
	BEGIN
		SELECT @tempStartRun = GETDATE(), @LicenseeId = NULL, @logSPData = NULL, @logSPOlddata = NULL
		
		IF EXISTS (SELECT TOP 1 1 FROM @tblLicenseebefore)
		BEGIN
			SELECT TOP 1 @LicenseeId = LicenseeId FROM @tblLicenseebefore ORDER BY LicenseeId

			DELETE @Licensee
			DELETE @tblLicenseebefore OUTPUT DELETED.LicenseeId, DELETED.LaunchDate, DELETED.TerminationDate INTO @Licensee WHERE LicenseeId = @LicenseeId

			SET @xml = (SELECT	l.LicenseeId		AS '@lid'
								,l.LicenseeName		AS '@ln'
								,(SELECT	p.ProductId			AS '@pid'
											,p.ProductName		AS '@pn'
											,lp.LaunchDate		AS '@lld'
											,lp.TerminationDate	AS '@ltd'
								FROM (
									SELECT	@ProductId AS ProductId, LaunchDate, TerminationDate
									FROM @Licensee
									UNION ALL
									SELECT	ProductId, LaunchDate, TerminationDate
									FROM LicenseeProduct WITH(NOLOCK)
									WHERE ProductId <> @ProductId
										AND LicenseeId = @LicenseeId
								) AS lp
									INNER JOIN dbo.Product p WITH(NOLOCK) ON lp.ProductId = p.ProductId
								ORDER BY p.[Order]
								FOR XML PATH('row'), ROOT('lp'), TYPE
								)
						FROM dbo.Licensee l WITH(NOLOCK)
						WHERE l.LicenseeId = @LicenseeId
						FOR XML PATH('r'), TYPE
			)
			SELECT @logSPOlddata = CONVERT(NVARCHAR(MAX), @xml)

			BEGIN
				DELETE @tblLicenseeoffered WHERE LicenseeId = @LicenseeId

				SET @xml = (SELECT	l.LicenseeId		AS '@lid'
									,l.LicenseeName		AS '@ln'
									,(SELECT	p.ProductId			AS '@pid'
												,p.ProductName		AS '@pn'
												,lp.LaunchDate		AS '@lld'
												,lp.TerminationDate	AS '@ltd'
									FROM LicenseeProduct lp WITH(NOLOCK)
										INNER JOIN Product p WITH(NOLOCK) ON lp.ProductId = p.ProductId AND lp.LicenseeId = @LicenseeId
									ORDER BY p.[Order]
									FOR XML PATH('row'), ROOT('lp'), TYPE
									)
							FROM dbo.Licensee l WITH(NOLOCK)
							WHERE l.LicenseeId = @LicenseeId
							FOR XML PATH('r'), TYPE
				)
				SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
			END
		END
		ELSE IF EXISTS (SELECT TOP 1 1 FROM @tblLicenseeoffered)
		BEGIN
			SELECT TOP 1 @LicenseeId = LicenseeId FROM @tblLicenseeoffered ORDER BY LicenseeId

			DELETE @tblLicenseeoffered WHERE LicenseeId = @LicenseeId

			SET @xml = (SELECT	l.LicenseeId		AS '@lid'
								,l.LicenseeName		AS '@ln'
								,(SELECT	p.ProductId			AS '@pid'
											,p.ProductName		AS '@pn'
											,lp.LaunchDate		AS '@lld'
											,lp.TerminationDate	AS '@ltd'
								FROM LicenseeProduct lp WITH(NOLOCK)
									INNER JOIN Product p WITH(NOLOCK) ON lp.ProductId = p.ProductId AND lp.LicenseeId = @LicenseeId
								WHERE p.ProductId <> @ProductId
								ORDER BY p.[Order]
								FOR XML PATH('row'), ROOT('lp'), TYPE
								)
						FROM dbo.Licensee l WITH(NOLOCK)
						WHERE l.LicenseeId = @LicenseeId
						FOR XML PATH('r'), TYPE
			)
			SELECT @logSPOlddata = CONVERT(NVARCHAR(MAX), @xml)

			SET @xml = (SELECT	l.LicenseeId		AS '@lid'
								,l.LicenseeName		AS '@ln'
								,(SELECT	p.ProductId			AS '@pid'
											,p.ProductName		AS '@pn'
											,lp.LaunchDate		AS '@lld'
											,lp.TerminationDate	AS '@ltd'
								FROM LicenseeProduct lp WITH(NOLOCK)
									INNER JOIN Product p WITH(NOLOCK) ON lp.ProductId = p.ProductId AND lp.LicenseeId = @LicenseeId
								ORDER BY p.[Order]
								FOR XML PATH('row'), ROOT('lp'), TYPE
								)
						FROM dbo.Licensee l WITH(NOLOCK)
						WHERE l.LicenseeId = @LicenseeId
						FOR XML PATH('r'), TYPE
			)
			SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		END
		ELSE
			BREAK

		SELECT	@endRun		= GETDATE()  
				,@duration	= DATEDIFF(MILLISECOND, @startRun, @tempEndRun) + DATEDIFF(MILLISECOND, @tempStartRun, @endRun)

				EXEC dbo.OIC_LogRunSpIns
			@UserId			= @UserId
			,@SPName		= @procName
			,@Language		= @Language
			,@IP			= @IP
			,@Data          = @logSPData
			,@OldData       = @logSPOlddata
			,@Duration		= @Duration
	END
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeProductByProductUpd_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeProductByProductUpd_xtest    Script Date: 4/24/2017 10:21:28 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeProductByProductUpd_xtest]
    @ProductId           TINYINT
    ,@SelectedLicensee   XML				= NULL
    
    ,@UserId             INT
    ,@Language           VARCHAR(10)        = 'E'
    ,@IP                 VARCHAR(50)        = NULL
    ,@ErrCode            INT                = 0            OUTPUT
    ,@ErrMsg             VARCHAR(300)    = NULL        OUTPUT
AS
/*
    Created by: Kathy
    Date: 2015-04-03
    Task: Offer product to clients [Redmine:#29613]
    DB: DBOIC.bodb_OIC
    
    Revisions:
		- 20160513@Percy: add field terminationdate [RedmineID: #56935]
    
    Param's Explanation:
    - @SelectedLicensee: list of licensee                    
                <root>
                    <row LicenseeId="1" launchdate="2014-12-19" terminationdate="2016-05-13"/>
                    <row LicenseeId="3" launchdate="2014-12-19"/>
                </root>
    
    - Log:
        <root><xml path="r" />
            <row item="ProductId" alias="pid" />
            <row item="ProductName" alias="pn" />
            <row item="LicenseeId" alias="lid" />
            <row item="LicenseeName" alias="ln" />
            <row item="LaunchDate" alias="lpld" />
			<row item="TerminationDate" alias="lptd" />            
        </root>    
        
 */
BEGIN
    SET NOCOUNT ON
    
    
    -- For write log
    DECLARE 
        @startRun       DATETIME
        ,@endRun        DATETIME
        ,@duration      INT
        ,@logSPData     NVARCHAR(MAX)
        ,@logSPOlddata  NVARCHAR(MAX)    
        ,@xml           XML
        ,@procName      VARCHAR(200)
        ,@ProductName   VARCHAR(50)

		,@tempStartRun	DATETIME
		,@tempEndRun	DATETIME
    
    SET @startRun = GETDATE()
    
    DECLARE @tblLicenseeoffered TABLE (LicenseeId INT, LaunchDate DATETIME, TerminationDate DATETIME, IsDelete BIT DEFAULT 0)
	DECLARE @tblLicenseebefore TABLE (LicenseeId INT, LaunchDate DATETIME, TerminationDate DATETIME, IsDelete BIT DEFAULT 0)
    
    SELECT @ProductName = ProductName 
    FROM dbo.Product WITH(NOLOCK) 
    WHERE ProductId = @ProductId
    
    IF @@ROWCOUNT = 0
    BEGIN
        SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30000, @Language) -- Product does not exist.
        RETURN
    END
    
    INSERT INTO @tblLicenseeoffered (LicenseeId, LaunchDate, TerminationDate)
    SELECT	t.c.value('@LicenseeId','int') AS LicenseeId
			,t.c.value('@launchdate', 'datetime') AS LaunchDate
			,t.c.value('@terminationdate', 'datetime') AS TerminationDate
    FROM @SelectedLicensee.nodes('root/row') t(c)

	INSERT INTO @tblLicenseebefore (LicenseeId, LaunchDate, TerminationDate)
	SELECT	l.LicenseeId, lp.LaunchDate, lp.TerminationDate
	FROM dbo.Licensee AS l WITH (NOLOCK)
		INNER JOIN dbo.LicenseeProduct lp WITH(NOLOCK) ON l.LicenseeId = lp.LicenseeId 
	WHERE lp.ProductId = @ProductId
    
    IF @@ERROR <> 0
    BEGIN
        SELECT	@ErrCode = 102
                ,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1000,@Language) -- Fail to edit product's clients. Please try again.
        RETURN
    END
    
    -- get data before update/insert
    SET @xml = (SELECT	@ProductId                AS '@pid'
						,@ProductName                AS '@pn'
						,(SELECT	l.LicenseeId        AS '@lid'
									,l.LicenseeName        AS '@ln'
									,lp.LaunchDate        AS '@lpld'
									,lp.TerminationDate        AS '@lptd'
							FROM dbo.Licensee AS l WITH (NOLOCK)
								INNER JOIN dbo.LicenseeProduct lp WITH(NOLOCK) 
									ON	l.LicenseeId = lp.LicenseeId 
							WHERE lp.ProductId = @ProductId
							FOR XML PATH('row'), TYPE, ROOT('lp')
						)
				FOR XML PATH('r')
				)        
    SELECT @logSPOldData = CONVERT(NVARCHAR(MAX),@xml)
    
    BEGIN TRY
		MERGE dbo.LicenseeProduct AS lp
		USING (SELECT LicenseeId, LaunchDate, TerminationDate FROM @tblLicenseeoffered) AS t
			ON	(lp.LicenseeId = t.LicenseeId AND lp.ProductId = @ProductId)
		WHEN MATCHED AND (lp.LaunchDate <> t.LaunchDate OR ISNULL(lp.TerminationDate, '') <> ISNULL(t.TerminationDate, '')) THEN UPDATE SET lp.LaunchDate = t.LaunchDate, lp.TerminationDate = t.TerminationDate
		WHEN NOT MATCHED BY TARGET THEN INSERT (LicenseeId, ProductId, LaunchDate, TerminationDate) VALUES (t.LicenseeId, @ProductId, t.LaunchDate, t.TerminationDate);
		
		DELETE	dbo.LicenseeProduct WITH(ROWLOCK, UPDLOCK)
		WHERE	ProductId = @ProductId
				AND LicenseeId NOT IN (SELECT LicenseeId FROM @tblLicenseeoffered)
				
    END TRY
    BEGIN CATCH
        SELECT	@ErrCode = 103
                ,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1000, @Language) + ERROR_MESSAGE() -- Fail to edit product's clients. Please try again.
        RETURN
    END CATCH        

    -- Write log
    SET @xml = (SELECT	@ProductId						AS '@pid'
                        ,@ProductName					AS '@pn'
                        ,(SELECT l.LicenseeId			AS '@lid'
                                ,l.LicenseeName			AS '@ln'
                                ,lp.LaunchDate			AS '@lpld'
								,lp.TerminationDate			AS '@lptd'
                            FROM dbo.Licensee AS l WITH (NOLOCK)
								INNER JOIN dbo.LicenseeProduct lp WITH(NOLOCK) 
									ON	l.LicenseeId = lp.LicenseeId 
                            WHERE	l.LicenseeId IN (SELECT LicenseeId FROM @tblLicenseeoffered)
									AND lp.ProductId = @ProductId
                            FOR XML PATH('row'), TYPE, ROOT('lp')
                        )
                FOR XML PATH('r')
                )        
        
    SELECT @logSPData = CONVERT(NVARCHAR(MAX),@xml)
        ,@endRun    = GETDATE()  
        ,@duration    = DATEDIFF(MILLISECOND, @startRun, @endRun)   
        ,@procName    = OBJECT_NAME(@@PROCID)
    
    EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId         = @UserId
		,@SPName        = @procName
		,@Language      = @Language
		,@IP            = @IP
		,@Data          = @logSPData
		,@OldData       = @logSPOlddata
		,@Duration      = @Duration

	DECLARE @Licensee TABLE (LicenseeId INT, LaunchDate DATETIME, TerminationDate DATETIME)
	DECLARE @LicenseeId INT

	SELECT  @procName = SPName, @tempEndRun = GETDATE() FROM dbo.LogAction WITH(NOLOCK) WHERE LogActionId = 201 -- write log for client

	UPDATE b
	SET b.IsDelete = 1
	FROM @tblLicenseebefore b
		INNER JOIN @tblLicenseeoffered a ON b.LicenseeId = a.LicenseeId
	WHERE ISNULL(b.LaunchDate, CONVERT(DATETIME, '19700101')) = ISNULL(a.LaunchDate, CONVERT(DATETIME, '19700101'))
		AND ISNULL(b.TerminationDate, CONVERT(DATETIME, '19700101')) = ISNULL(a.TerminationDate, CONVERT(DATETIME, '19700101'))

	UPDATE a
	SET a.IsDelete = 1
	FROM @tblLicenseebefore b
		INNER JOIN @tblLicenseeoffered a ON b.LicenseeId = a.LicenseeId
	WHERE ISNULL(b.LaunchDate, CONVERT(DATETIME, '19700101')) = ISNULL(a.LaunchDate, CONVERT(DATETIME, '19700101'))
		AND ISNULL(b.TerminationDate, CONVERT(DATETIME, '19700101')) = ISNULL(a.TerminationDate, CONVERT(DATETIME, '19700101'))

	DELETE @tblLicenseebefore WHERE IsDelete = 1
	DELETE @tblLicenseeoffered WHERE IsDelete = 1

	WHILE 1=1
	BEGIN
		SELECT @tempStartRun = GETDATE(), @LicenseeId = NULL, @logSPData = NULL, @logSPOlddata = NULL
		
		IF EXISTS (SELECT TOP 1 1 FROM @tblLicenseebefore)
		BEGIN
			SELECT TOP 1 @LicenseeId = LicenseeId FROM @tblLicenseebefore ORDER BY LicenseeId

			DELETE @Licensee
			DELETE @tblLicenseebefore OUTPUT DELETED.LicenseeId, DELETED.LaunchDate, DELETED.TerminationDate INTO @Licensee WHERE LicenseeId = @LicenseeId

			SET @xml = (SELECT	l.LicenseeId		AS '@lid'
								,l.LicenseeName		AS '@ln'
								,(SELECT	p.ProductId			AS '@pid'
											,p.ProductName		AS '@pn'
											,lp.LaunchDate		AS '@lld'
											,lp.TerminationDate	AS '@ltd'
								FROM (
									SELECT	@ProductId AS ProductId, LaunchDate, TerminationDate
									FROM @Licensee
									UNION ALL
									SELECT	ProductId, LaunchDate, TerminationDate
									FROM LicenseeProduct WITH(NOLOCK)
									WHERE ProductId <> @ProductId
										AND LicenseeId = @LicenseeId
								) AS lp
									INNER JOIN dbo.Product p WITH(NOLOCK) ON lp.ProductId = p.ProductId
								ORDER BY p.[Order]
								FOR XML PATH('row'), ROOT('lp'), TYPE
								)
						FROM dbo.Licensee l WITH(NOLOCK)
						WHERE l.LicenseeId = @LicenseeId
						FOR XML PATH('r'), TYPE
			)
			SELECT @logSPOlddata = CONVERT(NVARCHAR(MAX), @xml)

			BEGIN
				DELETE @tblLicenseeoffered WHERE LicenseeId = @LicenseeId

				SET @xml = (SELECT	l.LicenseeId		AS '@lid'
									,l.LicenseeName		AS '@ln'
									,(SELECT	p.ProductId			AS '@pid'
												,p.ProductName		AS '@pn'
												,lp.LaunchDate		AS '@lld'
												,lp.TerminationDate	AS '@ltd'
									FROM LicenseeProduct lp WITH(NOLOCK)
										INNER JOIN Product p WITH(NOLOCK) ON lp.ProductId = p.ProductId AND lp.LicenseeId = @LicenseeId
									ORDER BY p.[Order]
									FOR XML PATH('row'), ROOT('lp'), TYPE
									)
							FROM dbo.Licensee l WITH(NOLOCK)
							WHERE l.LicenseeId = @LicenseeId
							FOR XML PATH('r'), TYPE
				)
				SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
			END
		END
		ELSE IF EXISTS (SELECT TOP 1 1 FROM @tblLicenseeoffered)
		BEGIN
			SELECT TOP 1 @LicenseeId = LicenseeId FROM @tblLicenseeoffered ORDER BY LicenseeId

			DELETE @tblLicenseeoffered WHERE LicenseeId = @LicenseeId

			SET @xml = (SELECT	l.LicenseeId		AS '@lid'
								,l.LicenseeName		AS '@ln'
								,(SELECT	p.ProductId			AS '@pid'
											,p.ProductName		AS '@pn'
											,lp.LaunchDate		AS '@lld'
											,lp.TerminationDate	AS '@ltd'
								FROM LicenseeProduct lp WITH(NOLOCK)
									INNER JOIN Product p WITH(NOLOCK) ON lp.ProductId = p.ProductId AND lp.LicenseeId = @LicenseeId
								WHERE p.ProductId <> @ProductId
								ORDER BY p.[Order]
								FOR XML PATH('row'), ROOT('lp'), TYPE
								)
						FROM dbo.Licensee l WITH(NOLOCK)
						WHERE l.LicenseeId = @LicenseeId
						FOR XML PATH('r'), TYPE
			)
			SELECT @logSPOlddata = CONVERT(NVARCHAR(MAX), @xml)

			SET @xml = (SELECT	l.LicenseeId		AS '@lid'
								,l.LicenseeName		AS '@ln'
								,(SELECT	p.ProductId			AS '@pid'
											,p.ProductName		AS '@pn'
											,lp.LaunchDate		AS '@lld'
											,lp.TerminationDate	AS '@ltd'
								FROM LicenseeProduct lp WITH(NOLOCK)
									INNER JOIN Product p WITH(NOLOCK) ON lp.ProductId = p.ProductId AND lp.LicenseeId = @LicenseeId
								ORDER BY p.[Order]
								FOR XML PATH('row'), ROOT('lp'), TYPE
								)
						FROM dbo.Licensee l WITH(NOLOCK)
						WHERE l.LicenseeId = @LicenseeId
						FOR XML PATH('r'), TYPE
			)
			SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		END
		ELSE
			BREAK

		SELECT	@endRun		= GETDATE()  
				,@duration	= DATEDIFF(MILLISECOND, @startRun, @tempEndRun) + DATEDIFF(MILLISECOND, @tempStartRun, @endRun)

		EXEC dbo.OIC_LogRunSpIns_xtest
			@UserId			= @UserId
			,@SPName		= @procName
			,@Language		= @Language
			,@IP			= @IP
			,@Data          = @logSPData
			,@OldData       = @logSPOlddata
			,@Duration		= @Duration
	END
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeProductListSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeProductListSel    Script Date: 9/11/2017 11:37:21 PM ******/
CREATE PROCEDURE [dbo].[OIC_LicenseeProductListSel] 
	@UserId				INT
	,@SelectedLicenseeType VARCHAR(50)	= 'All'
	,@LicenseeName		NVARCHAR(50)		= '%'
	,@LicenseeStatusIds	VARCHAR(50)	= 'All'
	,@SelectedProduct	VARCHAR(500)	= 'All'
	,@ProductShown		VARCHAR(500)
	,@ProductStatusId	TINYINT			= 0
	,@LaunchFrom		DATETIME		= NULL
	,@LaunchTo			DATETIME		= NULL
	,@TerminationFrom	DATETIME		= NULL
	,@TerminationTo		DATETIME		= NULL
		
	,@PageSize			INT = 10
	,@PageIndex			INT	= 0 
	,@TotalRecords		INT = 0 OUTPUT
AS
/*
	Created by: Kathy
	Date: 2015-03-31
	Task: Licensee product list [Redmine:#29613]
	DB: DBOIC/BODB_OIC 
	
	Revisions:
		- 20160513@Percy: Add filter launched and terminated date [RedmineID: #56935]
		- 20161214@Percy: Change dropdown TOL filter multiple choices [RedmineID: #68774]
		- 20170828@Scofield: Update LicenseeStatusIds [#82144]
	
	Param's Explanation:
		@SelectedProduct: multiple selection
		@ProductShown: list products shall be shown, support multiple selection
		@PageIndex: 0 - the first page
		@ProductStatusId:
			0: All
			1: Upcoming
			2: Launched
			3: To be terminated
			4: Terminated
		
 */
BEGIN
	SET NOCOUNT ON
	DECLARE @DynamicPIVOT		VARCHAR(MAX)
			,@strProductName	VARCHAR(MAX)
	
	DECLARE @RowCount	INT	
			,@RowStart	INT
			,@RowEnd	INT
	
	SELECT @PageIndex = @PageIndex,
			@RowStart = @PageSize * @PageIndex + 1
			,@RowEnd = @RowStart + @PageSize - 1
	
	DECLARE @today				DATETIME = CONVERT(DATE, GETDATE())
	DECLARE @tblProduct			TABLE (ProductId INT)
	DECLARE @tblLicenseeType	TABLE (LicenseeTypeId TINYINT)
	CREATE TABLE #tblLicenseeProduct (LicenseeId INT, ProductId INT, IsFilled BIT)
	
	CREATE TABLE #tblResult	(
		RowNumber			INT
		,LicenseeId			INT
		,LicenseeName		NVARCHAR(50)
		,StatusName			VARCHAR(30)
		,TypeName			VARCHAR(30)
	)
							
	INSERT INTO @tblProduct(ProductId)
	SELECT	p.ProductId
	FROM	dbo.Product p WITH(NOLOCK)
	WHERE   @SelectedProduct = 'All' 
			OR p.ProductId IN (SELECT val FROM dbo.strSplit(@SelectedProduct,','))
					
	INSERT INTO #tblLicenseeProduct(LicenseeId, ProductId, IsFilled)
	SELECT	lp.LicenseeId, p.ProductId, 0
	FROM	@tblProduct p				
		RIGHT JOIN dbo.LicenseeProduct lp WITH(NOLOCK) 
			ON	p.ProductId = lp.ProductId

	UPDATE t
	SET IsFilled = 1
	FROM #tblLicenseeProduct t	
		INNER JOIN dbo.LicenseeProduct lp WITH(NOLOCK) 
			ON	t.LicenseeId = lp.LicenseeId AND t.ProductId = lp.ProductId
	WHERE
		(@LaunchFrom IS NULL
			OR (@LaunchFrom IS NOT NULL AND lp.LaunchDate >= @LaunchFrom))
		AND (@LaunchTo IS NULL
			OR (@LaunchTo IS NOT NULL AND lp.LaunchDate <= @LaunchTo))
		AND (@TerminationFrom IS NULL
			OR (@TerminationFrom IS NOT NULL AND lp.TerminationDate >= @TerminationFrom))
		AND (@TerminationTo IS NULL
			OR (@TerminationTo IS NOT NULL AND lp.TerminationDate <= @TerminationTo))
		AND (@ProductStatusId = 0
			OR (@ProductStatusId = 1 AND lp.LaunchDate > @today)
			OR (@ProductStatusId = 2 AND lp.LaunchDate <= @today)
			OR (@ProductStatusId = 3 AND lp.LaunchDate <= @today AND lp.TerminationDate IS NOT NULL)
			OR (@ProductStatusId = 4 AND lp.TerminationDate < @today))

	IF @SelectedLicenseeType = 'All'
	BEGIN
		INSERT INTO @tblLicenseeType (LicenseeTypeId)
		SELECT	LicenseeTypeId
		FROM	dbo.UserLicenseeType WITH(NOLOCK)
		WHERE	UserId = @UserId
	END
	ELSE
	BEGIN
		INSERT INTO @tblLicenseeType (LicenseeTypeId)
		SELECT CONVERT(TINYINT, val) FROM dbo.strSplit(@SelectedLicenseeType, ',')

		DELETE lt
		FROM @tblLicenseeType lt
			LEFT JOIN dbo.UserLicenseeType ult WITH(NOLOCK) ON lt.LicenseeTypeId = ult.LicenseeTypeId AND ult.UserId = @UserId
		WHERE ult.LicenseeTypeId IS NULL
	END
					
	INSERT INTO #tblResult( 
			RowNumber
			,LicenseeId
			,LicenseeName
			,StatusName
			,TypeName
	)	
	SELECT	ROW_NUMBER() OVER(ORDER BY LicenseeName) AS RowNumber
			, l.LicenseeId
			,l.LicenseeName
			,ls.LicenseeStatusName
			,lt.LicenseeTypeName
	FROM	dbo.Licensee l
		INNER JOIN LicenseeType lt 
			ON	l.licenseeTypeId = lt.LicenseeTypeId
		INNER JOIN LicenseeStatus ls 
			ON	l.LicenseeStatusId = ls.LicenseeStatusId
	WHERE	l.LicenseeTypeId IN (SELECT LicenseeTypeId FROM @tblLicenseeType)
			AND l.LicenseeName LIKE ISNULL(@LicenseeName,'%') + '%'
			AND (@LicenseeStatusIds = 'All' OR l.LicenseeStatusId IN (SELECT val FROM dbo.strSplit(@LicenseeStatusIds,','))) 	
	GROUP BY l.LicenseeId
			,l.LicenseeName
			,ls.LicenseeStatusName
			,lt.LicenseeTypeName						
	
	IF @TotalRecords = 0
	BEGIN
		SELECT @TotalRecords = COUNT(1)
		FROM #tblResult
	END
			
	SELECT	@strProductName = ISNULL(@strProductName, '') + '[' +  productname + '],'
	FROM	dbo.Product
	WHERE	ProductId IN (SELECT val FROM dbo.strSplit(@ProductShown,','))
	ORDER BY [Order]
	
	SELECT @strProductName = LEFT(@strProductName,LEN(@strProductName) -1)	
	
	SELECT @DynamicPIVOT = 'SELECT LicenseeId
								,LicenseeName
								,StatusName
								,TypeName
								,' + @strProductName +
	'FROM (
			SELECT	 RowNumber, t.LicenseeId, t.LicenseeName, t.StatusName, t.TypeName, p.productname
			,CONVERT(VARCHAR(1), ISNULL(IsFilled, 0)) + '','' + CONVERT(VARCHAR(10), lp.LaunchDate, 20) + CASE WHEN ISNULL(lp.TerminationDate, '''') <> ''''THEN + '','' + CONVERT(VARCHAR(10), lp.TerminationDate, 20) ELSE '''' END AS [Date]
			FROM	 #tblResult t WITH(NOLOCK)
				LEFT JOIN dbo.LicenseeProduct lp
					ON	t.LicenseeId = lp.LicenseeId				
				LEFT JOIN dbo.Product p WITH(NOLOCK)
					ON	lp.ProductId = p.ProductId
				LEFT JOIN #tblLicenseeProduct tlp
					ON t.LicenseeId = tlp.LicenseeId AND lp.ProductId = tlp.ProductId
		 )p
	PIVOT (
		MAX(p.[Date]) FOR productname IN (' + @strProductName + ')
	) Result
	WHERE RowNumber BETWEEN ' + CONVERT(VARCHAR(10),@RowStart) + ' AND ' + CONVERT(VARCHAR(10),@RowEnd) + ''
	
	EXEC (@DynamicPIVOT)
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeProductListSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OIC_LicenseeProductListSel_xtest] 
	@UserId				INT
	,@SelectedLicenseeType VARCHAR(50)	= 'All'
	,@LicenseeName		NVARCHAR(50)		= '%'
	,@LicenseeStatusIds	VARCHAR(50)	= 'All'
	,@SelectedProduct	VARCHAR(500)	= 'All'
	,@ProductShown		VARCHAR(500)
	,@ProductStatusId	TINYINT			= 0
	,@LaunchFrom		DATETIME		= NULL
	,@LaunchTo			DATETIME		= NULL
	,@TerminationFrom	DATETIME		= NULL
	,@TerminationTo		DATETIME		= NULL
		
	,@PageSize			INT = 10
	,@PageIndex			INT	= 0 
	,@TotalRecords		INT = 0 OUTPUT
AS
/*
	Created by: Kathy
	Date: 2015-03-31
	Task: Licensee product list [Redmine:#29613]
	DB: DBOIC/BODB_OIC 
	
	Revisions:
		- 20160513@Percy: Add filter launched and terminated date [RedmineID: #56935]
		- 20161214@Percy: Change dropdown TOL filter multiple choices [RedmineID: #68774]
		- 20170828@Scofield: Update LicenseeStatusIds [#82144]
	
	Param's Explanation:
		@SelectedProduct: multiple selection
		@ProductShown: list products shall be shown, support multiple selection
		@PageIndex: 0 - the first page
		@ProductStatusId:
			0: All
			1: Upcoming
			2: Launched
			3: To be terminated
			4: Terminated
		
 */
BEGIN
	SET NOCOUNT ON
	DECLARE @DynamicPIVOT		VARCHAR(MAX)
			,@strProductName	VARCHAR(MAX)
	
	DECLARE @RowCount	INT	
			,@RowStart	INT
			,@RowEnd	INT
	
	SELECT @PageIndex = @PageIndex,
			@RowStart = @PageSize * @PageIndex + 1
			,@RowEnd = @RowStart + @PageSize - 1
	
	DECLARE @today				DATETIME = CONVERT(DATE, GETDATE())
	DECLARE @tblProduct			TABLE (ProductId INT)
	DECLARE @tblLicenseeType	TABLE (LicenseeTypeId TINYINT)
	CREATE TABLE #tblLicenseeProduct (LicenseeId INT, ProductId INT, IsFilled BIT)
	
	CREATE TABLE #tblResult	(
		RowNumber			INT
		,LicenseeId			INT
		,LicenseeName		NVARCHAR(50)
		,StatusName			VARCHAR(30)
		,TypeName			VARCHAR(30)
	)
							
	INSERT INTO @tblProduct(ProductId)
	SELECT	p.ProductId
	FROM	dbo.Product p WITH(NOLOCK)
	WHERE   @SelectedProduct = 'All' 
			OR p.ProductId IN (SELECT val FROM dbo.strSplit(@SelectedProduct,','))
					
	INSERT INTO #tblLicenseeProduct(LicenseeId, ProductId, IsFilled)
	SELECT	lp.LicenseeId, p.ProductId, 0
	FROM	@tblProduct p				
		RIGHT JOIN dbo.LicenseeProduct lp WITH(NOLOCK) 
			ON	p.ProductId = lp.ProductId

	UPDATE t
	SET IsFilled = 1
	FROM #tblLicenseeProduct t	
		INNER JOIN dbo.LicenseeProduct lp WITH(NOLOCK) 
			ON	t.LicenseeId = lp.LicenseeId AND t.ProductId = lp.ProductId
	WHERE
		(@LaunchFrom IS NULL
			OR (@LaunchFrom IS NOT NULL AND lp.LaunchDate >= @LaunchFrom))
		AND (@LaunchTo IS NULL
			OR (@LaunchTo IS NOT NULL AND lp.LaunchDate <= @LaunchTo))
		AND (@TerminationFrom IS NULL
			OR (@TerminationFrom IS NOT NULL AND lp.TerminationDate >= @TerminationFrom))
		AND (@TerminationTo IS NULL
			OR (@TerminationTo IS NOT NULL AND lp.TerminationDate <= @TerminationTo))
		AND (@ProductStatusId = 0
			OR (@ProductStatusId = 1 AND lp.LaunchDate > @today)
			OR (@ProductStatusId = 2 AND lp.LaunchDate <= @today)
			OR (@ProductStatusId = 3 AND lp.LaunchDate <= @today AND lp.TerminationDate IS NOT NULL)
			OR (@ProductStatusId = 4 AND lp.TerminationDate < @today))

	IF @SelectedLicenseeType = 'All'
	BEGIN
		INSERT INTO @tblLicenseeType (LicenseeTypeId)
		SELECT	LicenseeTypeId
		FROM	dbo.UserLicenseeType WITH(NOLOCK)
		WHERE	UserId = @UserId
	END
	ELSE
	BEGIN
		INSERT INTO @tblLicenseeType (LicenseeTypeId)
		SELECT CONVERT(TINYINT, val) FROM dbo.strSplit(@SelectedLicenseeType, ',')

		DELETE lt
		FROM @tblLicenseeType lt
			LEFT JOIN dbo.UserLicenseeType ult WITH(NOLOCK) ON lt.LicenseeTypeId = ult.LicenseeTypeId AND ult.UserId = @UserId
		WHERE ult.LicenseeTypeId IS NULL
	END
					
	INSERT INTO #tblResult( 
			RowNumber
			,LicenseeId
			,LicenseeName
			,StatusName
			,TypeName
	)	
	SELECT	ROW_NUMBER() OVER(ORDER BY LicenseeName) AS RowNumber
			, l.LicenseeId
			,l.LicenseeName
			,ls.LicenseeStatusName
			,lt.LicenseeTypeName
	FROM	dbo.Licensee l
		INNER JOIN LicenseeType lt 
			ON	l.licenseeTypeId = lt.LicenseeTypeId
		INNER JOIN LicenseeStatus ls 
			ON	l.LicenseeStatusId = ls.LicenseeStatusId
	WHERE	l.LicenseeTypeId IN (SELECT LicenseeTypeId FROM @tblLicenseeType)
			AND l.LicenseeName LIKE ISNULL(@LicenseeName,'%') + '%'
			AND (@LicenseeStatusIds = 'All' OR l.LicenseeStatusId IN (SELECT val FROM dbo.strSplit(@LicenseeStatusIds,','))) 	
	GROUP BY l.LicenseeId
			,l.LicenseeName
			,ls.LicenseeStatusName
			,lt.LicenseeTypeName						
	
	IF @TotalRecords = 0
	BEGIN
		SELECT @TotalRecords = COUNT(1)
		FROM #tblResult
	END
			
	SELECT	@strProductName = ISNULL(@strProductName, '') + '[' +  productname + '],'
	FROM	dbo.Product
	WHERE	ProductId IN (SELECT val FROM dbo.strSplit(@ProductShown,','))
	ORDER BY [Order]
	
	SELECT @strProductName = LEFT(@strProductName,LEN(@strProductName) -1)	
	
	SELECT @DynamicPIVOT = 'SELECT LicenseeId
								,LicenseeName
								,StatusName
								,TypeName
								,' + @strProductName +
	'FROM (
			SELECT	 RowNumber, t.LicenseeId, t.LicenseeName, t.StatusName, t.TypeName, p.productname
			,CONVERT(VARCHAR(1), ISNULL(IsFilled, 0)) + '','' + CONVERT(VARCHAR(10), lp.LaunchDate, 20) + CASE WHEN ISNULL(lp.TerminationDate, '''') <> ''''THEN + '','' + CONVERT(VARCHAR(10), lp.TerminationDate, 20) ELSE '''' END AS [Date]
			FROM	 #tblResult t WITH(NOLOCK)
				LEFT JOIN dbo.LicenseeProduct lp
					ON	t.LicenseeId = lp.LicenseeId				
				LEFT JOIN dbo.Product p WITH(NOLOCK)
					ON	lp.ProductId = p.ProductId
				LEFT JOIN #tblLicenseeProduct tlp
					ON t.LicenseeId = tlp.LicenseeId AND lp.ProductId = tlp.ProductId
		 )p
	PIVOT (
		MAX(p.[Date]) FOR productname IN (' + @strProductName + ')
	) Result
	WHERE RowNumber BETWEEN ' + CONVERT(VARCHAR(10),@RowStart) + ' AND ' + CONVERT(VARCHAR(10),@RowEnd) + ''
	
	EXEC (@DynamicPIVOT)
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeSel    Script Date: 22/05/2015 10:07:47 AM ******/
CREATE PROCEDURE [dbo].[OIC_LicenseeSel]
	@LicenseeTypeId TINYINT = 0
AS
/*
	Created by: Kathy
	Date: 2015-02-04
	Task: Licensee List [Redmine:#29610]
	DB: DBOIC.bodb_OIC 
	
	Revisions:
	
	Param's Explanation:
	* @LicenseeTypeId: 0 - show all licensee
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT	l.LicenseeId
			,l.LicenseeName
	FROM dbo.Licensee l WITH(NOLOCK)
	WHERE	l.LicenseeTypeId = @LicenseeTypeId 
			OR @LicenseeTypeId = 0
	ORDER BY l.LicenseeName
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeStatusSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeStatusSel    Script Date: 15/05/2015 10:19:14 AM ******/
CREATE PROCEDURE [dbo].[OIC_LicenseeStatusSel]
AS

/*
	Created by: Dom
	Date: 2014-12-18
	Task: Get Licensee Status [Redmine:#27752]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		
 */

BEGIN
	SET NOCOUNT ON;
	
	SELECT	LicenseeStatusId
			,LicenseeStatusName AS Statusname
	FROM dbo.LicenseeStatus WITH(NOLOCK)  
END


GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeTypeAssign]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeTypeAssign    Script Date: 11/21/2016 10:54:24 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeTypeAssign    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeTypeAssign]
	@updUserId				INT
	,@SelectedLicenseeType	VARCHAR(100)
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS

/*
	Created by: Kathy
	Date: 20151006
	Task: assign licensee type to user  [Redmine:#44257]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160805@Percy: Add column Email of LicenseeType [RedmineID: #61904]
*/

BEGIN
	SET NOCOUNT ON
			
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPOlddata	NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
		,@isNewUser		BIT = 0
		,@username		NVARCHAR(50)
		,@newDisplayName NVARCHAR(50)
		,@errLicenseeType NVARCHAR(300) = ''

	DECLARE @tblLicenseeType TABLE (LicenseeTypeId TINYINT)
	
	SET @startRun = GETDATE()
	
	INSERT INTO @tblLicenseeType (LicenseeTypeId)
	SELECT val FROM dbo.strSplit (@SelectedLicenseeType,',')
	
	SELECT @errLicenseeType = ISNULL (@errLicenseeType, '' ) + lt.LicenseeTypeName + ','
	FROM	dbo.UserLicensee ul WITH(NOLOCK)
		INNER JOIN dbo.Licensee l WITH(NOLOCK)
			ON l.LicenseeId = ul.LicenseeId
		INNER JOIN dbo.LicenseeType lt WITH(NOLOCK)
			ON lt.LicenseeTypeId = l.LicenseeTypeId
	WHERE	ul.UserId = @updUserId
			AND l.LicenseeTypeId NOT IN (SELECT LicenseeTypeId FROM @tblLicenseeType)
	GROUP BY l.LicenseeTypeId, lt.LicenseeTypeName
	
	-- If the user is AM or PM, check if there is any client assigned to him.
	IF @errLicenseeType <> ''
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30024, @Language) + SUBSTRING(@errLicenseeType, 0, LEN(@errLicenseeType))  -- Fail to edit user's Type of Licensee. The user is currently the AM/PM of one or many client(s) of:
		RETURN
	END
	
	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE UserId = @updUserId)
	BEGIN
		SELECT	@newDisplayName = username
		FROM	bodb02.dbo.custInfo WITH(NOLOCK) 
		WHERE	custid = @updUserId 
				AND roleid >= 5
		
		IF @@ROWCOUNT = 0
		BEGIN
			SELECT	@ErrCode = 101
					,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30021, @Language) -- User does not exist
			RETURN
		END
		
		SET @isNewUser = 1
		
		IF EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE DisplayName = @newDisplayName)
		BEGIN
			DECLARE @seq INT = 1
			WHILE(1 = 1)
			BEGIN
				IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE DisplayName = @newDisplayName +' (' + CAST(@seq AS VARCHAR(10)) +')') 
				BEGIN
					SET @newDisplayName = @newDisplayName +' (' + CAST(@seq AS VARCHAR(10)) +')' 
					
					BREAK
				END
				
				SET @seq = @seq + 1
			END
		END
	END
	
	SET @xml = (SELECT @updUserId AS '@uid',
						(SELECT lt.LicenseeTypeId		AS '@lti'
								,lt.LicenseeTypeName	AS '@ltn'
						FROM	UserLicenseeType ult WITH(NOLOCK)
							INNER JOIN dbo.LicenseeType lt WITH (NOLOCK) ON ult.LicenseeTypeId = lt.LicenseeTypeId
						WHERE	UserId = @updUserId
						FOR XML PATH('row'), ROOT('lt'), TYPE
						)
				FOR XML PATH('r'), TYPE
				)
	
	SELECT @logSPOlddata = CONVERT(NVARCHAR(MAX), @xml)
	
	BEGIN TRY
		IF @isNewUser = 1
		BEGIN
			INSERT INTO dbo.UserInfo (UserId, DisplayName) VALUES (@updUserId, @newDisplayName)
		END

		DECLARE @Email VARCHAR(50)
		SELECT  @Email = Email FROM dbo.UserInfo WITH(NOLOCK) WHERE UserId = @updUserId
		
		MERGE dbo.UserLicenseeType AS ult
		USING (SELECT LicenseeTypeId FROM @tblLicenseeType) AS t
		ON (ult.LicenseeTypeId = t.LicenseeTypeId)
			AND ult.UserId = @updUserId
		WHEN NOT MATCHED BY TARGET THEN INSERT (UserId, LicenseeTypeId, Email) VALUES (@updUserId, t.LicenseeTypeId, @Email)
		WHEN NOT MATCHED BY SOURCE AND ult.UserId = @updUserId THEN DELETE;		
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30025,@Language) + ERROR_MESSAGE() -- Fail to edit user's Type of Licensee. Please try again.
		
		RETURN
	END CATCH
	
	SET @xml = (SELECT @updUserId AS '@uid',
						(SELECT lt.LicenseeTypeId		AS '@lti'
								,lt.LicenseeTypeName	AS '@ltn'
						FROM	UserLicenseeType ult WITH(NOLOCK)
							INNER JOIN dbo.LicenseeType lt WITH (NOLOCK) ON ult.LicenseeTypeId = lt.LicenseeTypeId
						WHERE	UserId = @updUserId
						FOR XML PATH('row'), ROOT('lt'), TYPE
						)
				FOR XML PATH('r'), TYPE
				)
	
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

		EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOlddata
		,@Duration		= @Duration	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeTypeAssign_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeTypeAssign_xtest    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeTypeAssign_xtest]
	@updUserId				INT
	,@SelectedLicenseeType	VARCHAR(100)
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS

/*
	Created by: Kathy
	Date: 20151006
	Task: assign licensee type to user  [Redmine:#44257]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160805@Percy: Add column Email of LicenseeType [RedmineID: #61904]
*/

BEGIN
	SET NOCOUNT ON
			
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPOlddata	NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
		,@isNewUser		BIT = 0
		,@username		NVARCHAR(50)
		,@newDisplayName NVARCHAR(50)
		,@errLicenseeType NVARCHAR(300) = ''

	DECLARE @tblLicenseeType TABLE (LicenseeTypeId TINYINT)
	
	SET @startRun = GETDATE()
	
	INSERT INTO @tblLicenseeType (LicenseeTypeId)
	SELECT val FROM dbo.strSplit (@SelectedLicenseeType,',')
	
	SELECT @errLicenseeType = ISNULL (@errLicenseeType, '' ) + lt.LicenseeTypeName + ','
	FROM	dbo.UserLicensee ul WITH(NOLOCK)
		INNER JOIN dbo.Licensee l WITH(NOLOCK)
			ON l.LicenseeId = ul.LicenseeId
		INNER JOIN dbo.LicenseeType lt WITH(NOLOCK)
			ON lt.LicenseeTypeId = l.LicenseeTypeId
	WHERE	ul.UserId = @updUserId
			AND l.LicenseeTypeId NOT IN (SELECT LicenseeTypeId FROM @tblLicenseeType)
	GROUP BY l.LicenseeTypeId, lt.LicenseeTypeName
	
	-- If the user is AM or PM, check if there is any client assigned to him.
	IF @errLicenseeType <> ''
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30024, @Language) + SUBSTRING(@errLicenseeType, 0, LEN(@errLicenseeType))  -- Fail to edit user's Type of Licensee. The user is currently the AM/PM of one or many client(s) of:
		RETURN
	END
	
	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE UserId = @updUserId)
	BEGIN
		SELECT	@newDisplayName = username
		FROM	bodb02.dbo.custInfo WITH(NOLOCK) 
		WHERE	custid = @updUserId 
				AND roleid >= 5
		
		IF @@ROWCOUNT = 0
		BEGIN
			SELECT	@ErrCode = 101
					,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30021, @Language) -- User does not exist
			RETURN
		END
		
		SET @isNewUser = 1
		
		IF EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE DisplayName = @newDisplayName)
		BEGIN
			DECLARE @seq INT = 1
			WHILE(1 = 1)
			BEGIN
				IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE DisplayName = @newDisplayName +' (' + CAST(@seq AS VARCHAR(10)) +')') 
				BEGIN
					SET @newDisplayName = @newDisplayName +' (' + CAST(@seq AS VARCHAR(10)) +')' 
					
					BREAK
				END
				
				SET @seq = @seq + 1
			END
		END
	END
	
	SET @xml = (SELECT @updUserId AS '@uid',
						(SELECT lt.LicenseeTypeId		AS '@lti'
								,lt.LicenseeTypeName	AS '@ltn'
						FROM	UserLicenseeType ult WITH(NOLOCK)
							INNER JOIN dbo.LicenseeType lt WITH (NOLOCK) ON ult.LicenseeTypeId = lt.LicenseeTypeId
						WHERE	UserId = @updUserId
						FOR XML PATH('row'), ROOT('lt'), TYPE
						)
				FOR XML PATH('r'), TYPE
				)
	
	SELECT @logSPOlddata = CONVERT(NVARCHAR(MAX), @xml)
	
	BEGIN TRY
		IF @isNewUser = 1
		BEGIN
			INSERT INTO dbo.UserInfo (UserId, DisplayName) VALUES (@updUserId, @newDisplayName)
		END

		DECLARE @Email VARCHAR(50)
		SELECT  @Email = Email FROM dbo.UserInfo WITH(NOLOCK) WHERE UserId = @updUserId
		
		MERGE dbo.UserLicenseeType AS ult
		USING (SELECT LicenseeTypeId FROM @tblLicenseeType) AS t
		ON (ult.LicenseeTypeId = t.LicenseeTypeId)
			AND ult.UserId = @updUserId
		WHEN NOT MATCHED BY TARGET THEN INSERT (UserId, LicenseeTypeId, Email) VALUES (@updUserId, t.LicenseeTypeId, @Email)
		WHEN NOT MATCHED BY SOURCE AND ult.UserId = @updUserId THEN DELETE;		
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30025,@Language) + ERROR_MESSAGE() -- Fail to edit user's Type of Licensee. Please try again.
		
		RETURN
	END CATCH
	
	SET @xml = (SELECT @updUserId AS '@uid',
						(SELECT lt.LicenseeTypeId		AS '@lti'
								,lt.LicenseeTypeName	AS '@ltn'
						FROM	UserLicenseeType ult WITH(NOLOCK)
							INNER JOIN dbo.LicenseeType lt WITH (NOLOCK) ON ult.LicenseeTypeId = lt.LicenseeTypeId
						WHERE	UserId = @updUserId
						FOR XML PATH('row'), ROOT('lt'), TYPE
						)
				FOR XML PATH('r'), TYPE
				)
	
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOlddata
		,@Duration		= @Duration	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeTypeAssignmentList]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeTypeAssignmentList    Script Date: 11/21/2016 10:54:24 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeTypeAssignmentList    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeTypeAssignmentList] 
	@DisplayName			NVARCHAR(50)	= '%'
	,@SelectedPosition		VARCHAR(100)	= 'All'
	,@SelectedLicenseeType	VARCHAR(100)	= 'All'
	,@SiteId				INT  
AS

/*
	Created by: Kathy
	Date: 20151006
	Task: list licensee type of user  [Redmine:#44257]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		@PositionId: All - ALL position
		@SiteId: siteid on NAP Home
 */

BEGIN
	SET NOCOUNT ON;
			
	DECLARE @DynamicPIVOT		VARCHAR(MAX)
			,@strLicenseeType VARCHAR(MAX)
			
	SELECT	@strLicenseeType = ISNULL(@strLicenseeType, '') + '[' + LicenseeTypeName + '],'
	FROM	dbo.LicenseeType WITH(NOLOCK)
	
	SELECT @strLicenseeType = LEFT(@strLicenseeType,LEN(@strLicenseeType) -1)	
	
	SELECT	ci.custid AS UserId
			,CASE WHEN ISNULL(ui.DisplayName,'') = '' THEN ci.username ELSE ui.DisplayName END AS DisplayName
			,p.PositionName
	INTO	#tblResult
	FROM	bodb_NAP.dbo.Users u WITH(NOLOCK)
		INNER JOIN bodb_NAP.dbo.UserSite us WITH(NOLOCK) ON u.UserId = us.UserId
		INNER JOIN bodb02.dbo.custInfo ci WITH(NOLOCK)
			ON	ci.custid = us.UserId
		LEFT JOIN dbo.UserInfo ui WITH(NOLOCK)
			ON ui.UserId = ci.custid
		LEFT JOIN dbo.Position p WITH(NOLOCK)
			ON ui.PositionId = p.PositionId
		LEFT JOIN UserLicenseeType ul
			ON ci.custid = ul.UserId
	WHERE	us.SiteId = @SiteId
			AND us.IsActive = 1
			AND ISNULL(ui.DisplayName,ci.username) LIKE ISNULL(@DisplayName,ci.username) + '%'
			AND (@SelectedPosition = 'All' 
				OR (EXISTS (SELECT val FROM dbo.strSplit(@SelectedPosition,',') WHERE (val = 0 AND p.PositionId IS NULL) OR val = p.PositionId)) 
				)
			AND 1 = CASE WHEN @SelectedLicenseeType = 'All' THEN 1
						 WHEN EXISTS(SELECT val FROM dbo.strSplit(@SelectedLicenseeType,',') WHERE val = 0 AND ul.LicenseeTypeId IS NULL OR val = ul.LicenseeTypeId) THEN 1			
						 ELSE 0 
						 END
	GROUP BY ci.custid
			,CASE WHEN ISNULL(ui.DisplayName,'') = '' THEN ci.username ELSE ui.DisplayName END
			,p.PositionName
				
	SET @DynamicPIVOT = 'SELECT UserId
								,DisplayName
								,PositionName
								,' + @strLicenseeType + 
					'FROM
						(SELECT  t.UserId
									,t.DisplayName
									,t.PositionName
									,lt.LicenseeTypeId
									,lt.LicenseeTypeName
				
							FROM	#tblResult t
								LEFT JOIN dbo.UserLicenseeType ult WITH (NOLOCK)
									ON	ult.UserId = t.UserId
								LEFT JOIN dbo.LicenseeType lt WITH(NOLOCK)
									ON lt.LicenseeTypeId = ult.LicenseeTypeId							
						) l
					PIVOT (
						MAX(l.licenseeTypeId) FOR LicenseeTypeName IN (' + @strLicenseeType + ')
					) Result'
					
	EXEC (@DynamicPIVOT)
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeTypeAssignmentList_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeTypeAssignmentList_xtest    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeTypeAssignmentList_xtest] 
	@DisplayName			NVARCHAR(50)	= '%'
	,@SelectedPosition		VARCHAR(100)	= 'All'
	,@SelectedLicenseeType	VARCHAR(100)	= 'All'
	,@SiteId				INT  
AS

/*
	Created by: Kathy
	Date: 20151006
	Task: list licensee type of user  [Redmine:#44257]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		@PositionId: All - ALL position
		@SiteId: siteid on NAP Home
 */

BEGIN
	SET NOCOUNT ON;
			
	DECLARE @DynamicPIVOT		VARCHAR(MAX)
			,@strLicenseeType VARCHAR(MAX)
			
	SELECT	@strLicenseeType = ISNULL(@strLicenseeType, '') + '[' + LicenseeTypeName + '],'
	FROM	dbo.LicenseeType WITH(NOLOCK)
	
	SELECT @strLicenseeType = LEFT(@strLicenseeType,LEN(@strLicenseeType) -1)	
	
	SELECT	ci.custid AS UserId
			,CASE WHEN ISNULL(ui.DisplayName,'') = '' THEN ci.username ELSE ui.DisplayName END AS DisplayName
			,p.PositionName
	INTO	#tblResult
	FROM	bodb_NAP.dbo.Users u WITH(NOLOCK)
		INNER JOIN bodb_NAP.dbo.UserSite us WITH(NOLOCK) ON u.UserId = us.UserId
		INNER JOIN bodb02.dbo.custInfo ci WITH(NOLOCK)
			ON	ci.custid = us.UserId
		LEFT JOIN dbo.UserInfo ui WITH(NOLOCK)
			ON ui.UserId = ci.custid
		LEFT JOIN dbo.Position p WITH(NOLOCK)
			ON ui.PositionId = p.PositionId
		LEFT JOIN UserLicenseeType ul
			ON ci.custid = ul.UserId
	WHERE	us.SiteId = @SiteId
			AND us.IsActive = 1
			AND ISNULL(ui.DisplayName,ci.username) LIKE ISNULL(@DisplayName,ci.username) + '%'
			AND (@SelectedPosition = 'All' 
				OR (EXISTS (SELECT val FROM dbo.strSplit(@SelectedPosition,',') WHERE (val = 0 AND p.PositionId IS NULL) OR val = p.PositionId)) 
				)
			AND 1 = CASE WHEN @SelectedLicenseeType = 'All' THEN 1
						 WHEN EXISTS(SELECT val FROM dbo.strSplit(@SelectedLicenseeType,',') WHERE val = 0 AND ul.LicenseeTypeId IS NULL OR val = ul.LicenseeTypeId) THEN 1			
						 ELSE 0 
						 END
	GROUP BY ci.custid
			,CASE WHEN ISNULL(ui.DisplayName,'') = '' THEN ci.username ELSE ui.DisplayName END
			,p.PositionName
				
	SET @DynamicPIVOT = 'SELECT UserId
								,DisplayName
								,PositionName
								,' + @strLicenseeType + 
					'FROM
						(SELECT  t.UserId
									,t.DisplayName
									,t.PositionName
									,lt.LicenseeTypeId
									,lt.LicenseeTypeName
				
							FROM	#tblResult t
								LEFT JOIN dbo.UserLicenseeType ult WITH (NOLOCK)
									ON	ult.UserId = t.UserId
								LEFT JOIN dbo.LicenseeType lt WITH(NOLOCK)
									ON lt.LicenseeTypeId = ult.LicenseeTypeId							
						) l
					PIVOT (
						MAX(l.licenseeTypeId) FOR LicenseeTypeName IN (' + @strLicenseeType + ')
					) Result'
					
	EXEC (@DynamicPIVOT)
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeTypeDel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeTypeDel    Script Date: 11/21/2016 10:54:18 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeTypeDel    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeTypeDel] 
	@LicenseeTypeId			TINYINT
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: delete TOL [Redmine:#44251]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		
 */
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
	
	DECLARE @LicenseeTypeName VARCHAR(30)

	SET @startRun = GETDATE()		
	
	SELECT	@LicenseeTypeName = LicenseeTypeName
	FROM	dbo.LicenseeType WITH(NOLOCK)
	WHERE	LicenseeTypeId = @LicenseeTypeId
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.UserLicenseeType WITH(NOLOCK) WHERE LicenseeTypeId = @LicenseeTypeId)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30005, @Language) -- Unable to delete the type of licensee because one or many assigned client(s) or user(s) exist(s)
		RETURN
	END
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.Licensee WITH(NOLOCK) WHERE LicenseeTypeId = @LicenseeTypeId)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30005, @Language) -- Unable to delete the type of licensee because one or many assigned client(s) or user(s) exist(s)
		RETURN
	END
	
	BEGIN TRY
		DELETE
		FROM	dbo.LicenseeType WITH(ROWLOCK, UPDLOCK)
		WHERE	LicenseeTypeId = @LicenseeTypeId	
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30004, @Language) -- Fail to delete type of licensee. Please try again.
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	@LicenseeTypeId		AS '@lti'
				,@LicenseeTypeName	AS '@ltn'
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

		EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= NULL
		,@OldData		= @logSPData
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeTypeDel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeTypeDel_xtest    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeTypeDel_xtest] 
	@LicenseeTypeId			TINYINT
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: delete TOL [Redmine:#44251]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		
 */
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
	
	DECLARE @LicenseeTypeName VARCHAR(30)

	SET @startRun = GETDATE()		
	
	SELECT	@LicenseeTypeName = LicenseeTypeName
	FROM	dbo.LicenseeType WITH(NOLOCK)
	WHERE	LicenseeTypeId = @LicenseeTypeId
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.UserLicenseeType WITH(NOLOCK) WHERE LicenseeTypeId = @LicenseeTypeId)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30005, @Language) -- Unable to delete the type of licensee because one or many assigned client(s) or user(s) exist(s)
		RETURN
	END
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.Licensee WITH(NOLOCK) WHERE LicenseeTypeId = @LicenseeTypeId)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30005, @Language) -- Unable to delete the type of licensee because one or many assigned client(s) or user(s) exist(s)
		RETURN
	END
	
	BEGIN TRY
		DELETE
		FROM	dbo.LicenseeType WITH(ROWLOCK, UPDLOCK)
		WHERE	LicenseeTypeId = @LicenseeTypeId	
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30004, @Language) -- Fail to delete type of licensee. Please try again.
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	@LicenseeTypeId		AS '@lti'
				,@LicenseeTypeName	AS '@ltn'
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= NULL
		,@OldData		= @logSPData
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeTypeIns]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeTypeIns    Script Date: 11/21/2016 10:54:11 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeTypeIns    Script Date: 11/11/2016 10:29:58 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeTypeIns] 
	@LicenseeTypeName		VARCHAR(30)
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: insert new TOL [Redmine:#44251]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		
*/
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)

	DECLARE @LicenseeTypeId TINYINT

	SET @startRun = GETDATE()		
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.LicenseeType WITH(NOLOCK) WHERE LicenseeTypeName = @LicenseeTypeName)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30003, @Language) -- The licensee type name is already used. Please try another name.
		RETURN
	END
	
	BEGIN TRY
		INSERT INTO dbo.LicenseeType (LicenseeTypeName) VALUES (@LicenseeTypeName)
	
		SET @LicenseeTypeId = SCOPE_IDENTITY()
	
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30001, @Language) -- Fail to create type of licensee. Please try again.
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	@LicenseeTypeId		AS '@lti'
				,@LicenseeTypeName	AS '@ltn'
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

		EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeTypeIns_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeTypeIns_xtest    Script Date: 11/11/2016 10:29:58 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeTypeIns_xtest] 
	@LicenseeTypeName		VARCHAR(30)
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: insert new TOL [Redmine:#44251]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		
*/
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)

	DECLARE @LicenseeTypeId TINYINT

	SET @startRun = GETDATE()		
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.LicenseeType WITH(NOLOCK) WHERE LicenseeTypeName = @LicenseeTypeName)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30003, @Language) -- The licensee type name is already used. Please try another name.
		RETURN
	END
	
	BEGIN TRY
		INSERT INTO dbo.LicenseeType (LicenseeTypeName) VALUES (@LicenseeTypeName)
	
		SET @LicenseeTypeId = SCOPE_IDENTITY()
	
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30001, @Language) -- Fail to create type of licensee. Please try again.
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	@LicenseeTypeId		AS '@lti'
				,@LicenseeTypeName	AS '@ltn'
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeTypeSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeTypeSel    Script Date: 9/12/2016 11:46:46 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeTypeSel    Script Date: 9/12/2016 6:04:49 PM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeTypeSel]
	@UserId		INT	= 0
AS

/*
	Created by: Dom
	Date: 2014-12-18
	Task: Get Licensee Type belong to User [Redmine:#27752]
	DB: DBOIC.bodb_OIC 
	
	Revisions:
		- 20160823@Percy: Sort TOL by Id [RedmineID: #62883]
		
	Param's Explanation:
	*@UserId: 0 - show all LicenseeType without userid
 */

BEGIN
	SET NOCOUNT ON;

	SELECT lt.LicenseeTypeId
		,lt.LicenseeTypeName  AS TypeName
	FROM dbo.LicenseeType lt WITH(NOLOCK)
	WHERE @UserId = 0 OR lt.LicenseeTypeId IN (SELECT ul.LicenseeTypeId 
								FROM dbo.UserLicenseeType ul WITH(NOLOCK) 
								WHERE ul.UserId = @UserId)
	ORDER BY lt.LicenseeTypeId
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeTypeSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeTypeSel_xtest    Script Date: 9/12/2016 6:04:49 PM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeTypeSel_xtest]
	@UserId		INT	= 0
AS

/*
	Created by: Dom
	Date: 2014-12-18
	Task: Get Licensee Type belong to User [Redmine:#27752]
	DB: DBOIC.bodb_OIC 
	
	Revisions:
		- 20160823@Percy: Sort TOL by Id [RedmineID: #62883]
		
	Param's Explanation:
	*@UserId: 0 - show all LicenseeType without userid
 */

BEGIN
	SET NOCOUNT ON;

	SELECT lt.LicenseeTypeId
		,lt.LicenseeTypeName  AS TypeName
	FROM dbo.LicenseeType lt WITH(NOLOCK)
	WHERE @UserId = 0 OR lt.LicenseeTypeId IN (SELECT ul.LicenseeTypeId 
								FROM dbo.UserLicenseeType ul WITH(NOLOCK) 
								WHERE ul.UserId = @UserId)
	ORDER BY lt.LicenseeTypeId
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeTypeUpd]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeTypeUpd    Script Date: 11/21/2016 10:54:12 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LicenseeTypeUpd    Script Date: 11/11/2016 10:29:58 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeTypeUpd] 
	@LicenseeTypeId			TINYINT
	,@LicenseeTypeName		VARCHAR(30)
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: update TOL [Redmine:#44251]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		
*/
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPOlddata	NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)

	SET @startRun = GETDATE()
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.LicenseeType WITH(NOLOCK) WHERE LicenseeTypeName = @LicenseeTypeName)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30003, @Language) -- The licensee type name is already used. Please try another name.
		RETURN
	END		
	
	-- get old data
	SET @xml = (
		SELECT	LicenseeTypeId		AS '@lti'
				,LicenseeTypeName	AS '@ltn'
		FROM	dbo.LicenseeType WITH(NOLOCK)
		WHERE	LicenseeTypeId = @LicenseeTypeId
		FOR XML PATH('r'), TYPE
		)	
		
	SELECT @logSPOlddata = CONVERT(NVARCHAR(MAX), @xml)
	
	BEGIN TRY
		UPDATE	dbo.LicenseeType WITH(ROWLOCK, UPDLOCK)
			SET	LicenseeTypeName = @LicenseeTypeName
		WHERE	LicenseeTypeId = @LicenseeTypeId	
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30002, @Language) -- Fail to edit type of licensee. Please try again.	
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	LicenseeTypeId		AS '@lti'
				,LicenseeTypeName	AS '@ltn'
		FROM	dbo.LicenseeType WITH(NOLOCK)
		WHERE	LicenseeTypeId = @LicenseeTypeId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

		EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOlddata
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LicenseeTypeUpd_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LicenseeTypeUpd_xtest    Script Date: 11/11/2016 10:29:58 AM ******/

CREATE PROCEDURE [dbo].[OIC_LicenseeTypeUpd_xtest] 
	@LicenseeTypeId			TINYINT
	,@LicenseeTypeName		VARCHAR(30)
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: update TOL [Redmine:#44251]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		
*/
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPOlddata	NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)

	SET @startRun = GETDATE()
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.LicenseeType WITH(NOLOCK) WHERE LicenseeTypeName = @LicenseeTypeName)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30003, @Language) -- The licensee type name is already used. Please try another name.
		RETURN
	END		
	
	-- get old data
	SET @xml = (
		SELECT	LicenseeTypeId		AS '@lti'
				,LicenseeTypeName	AS '@ltn'
		FROM	dbo.LicenseeType WITH(NOLOCK)
		WHERE	LicenseeTypeId = @LicenseeTypeId
		FOR XML PATH('r'), TYPE
		)	
		
	SELECT @logSPOlddata = CONVERT(NVARCHAR(MAX), @xml)
	
	BEGIN TRY
		UPDATE	dbo.LicenseeType WITH(ROWLOCK, UPDLOCK)
			SET	LicenseeTypeName = @LicenseeTypeName
		WHERE	LicenseeTypeId = @LicenseeTypeId	
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30002, @Language) -- Fail to edit type of licensee. Please try again.	
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	LicenseeTypeId		AS '@lti'
				,LicenseeTypeName	AS '@ltn'
		FROM	dbo.LicenseeType WITH(NOLOCK)
		WHERE	LicenseeTypeId = @LicenseeTypeId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOlddata
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LocationSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LocationSel    Script Date: 15/05/2015 10:19:14 AM ******/
CREATE PROCEDURE [dbo].[OIC_LocationSel]
AS

/*
	Created by: Dom
	Date: 2014-12-18
	Task: Get Location [Redmine:#27752]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		
 */

BEGIN
	SET NOCOUNT ON;
	SELECT	LocationId
			,LocationName
	FROM dbo.Location WITH(NOLOCK)
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LogActionSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LogActionSel    Script Date: 1/8/2018 10:37:35 PM ******/
CREATE PROCEDURE [dbo].[OIC_LogActionSel]
	@ActionTypeID	TINYINT = 0, -- All
	@ActionID		INT = 0 -- All
AS
/*
	Creator: Percy
	Date: 2016-09-26
	DB: DBOIC.bodb_OIC
	Task: Select Log Action List [RedmineID: #64713]
	
	Revisions:	
		- 20171124@Scofield: #84004 - Update to show Notification LogActionType
*/
BEGIN
	SELECT
		lt.LogActionTypeId, lt.ActionTypeNameEn AS ActionTypeName, l.LogActionId, l.ActionNameEn AS ActionName
	FROM dbo.LogActionType lt WITH(NOLOCK)
		INNER JOIN dbo.LogAction l WITH(NOLOCK) ON lt.LogActionTypeId = l.LogActionTypeId
	WHERE [Enable] = 1
	ORDER BY [Order]
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LogActionSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OIC_LogActionSel_xtest]
	@ActionTypeID	TINYINT = 0, -- All
	@ActionID		INT = 0 -- All
AS
/*
	Creator: Percy
	Date: 2016-09-26
	DB: DBOIC.bodb_OIC
	Task: Select Log Action List [RedmineID: #64713]
	
	Revisions:	
		- 20171124@Scofield: #84004 - Update to show Notification LogActionType
*/
BEGIN
	SELECT
		lt.LogActionTypeId, lt.ActionTypeNameEn AS ActionTypeName, l.LogActionId, l.ActionNameEn AS ActionName
	FROM dbo.LogActionType lt WITH(NOLOCK)
		INNER JOIN dbo.LogAction l WITH(NOLOCK) ON lt.LogActionTypeId = l.LogActionTypeId
	WHERE [Enable] = 1
	ORDER BY [Order]
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LogListSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LogListSel    Script Date: 1/8/2018 10:37:35 PM ******/
CREATE PROCEDURE [dbo].[OIC_LogListSel]
	@UserId			INT,
	@FromDate		DATETIME,
	@ToDate			DATETIME,
	@ActionID		VARCHAR(MAX) = 'All', -- All
	@Target			VARCHAR(50) = '', -- All
	@DoneBy			VARCHAR(50) = '', -- All
		
	@PageSize		INT = 10,
	@PageIndex		INT	= 1,
	@TotalRecords	INT = 0 OUTPUT
AS
/*
	Creator: Percy
	Date: 2016-09-26
	DB: DBOIC.bodb_OIC
	Task: Select Log List [RedmineID: #64713]

	Revisions:
		- 20170328@Percy: Add new function: Client List [RemineID: #70323]
		- 20171019@Scofield: Update log for update Amendment Notification [#84004]

	Param's Explanation:
		- @ActionID: '1,2' -- List of LogActionID
*/
BEGIN
	DECLARE @FDate DATETIME, @TDate DATETIME -- prevent bad parameter sniffing
	SELECT  @FDate = @FromDate, @TDate = @ToDate

	SELECT  @ActionID = ISNULL(@ActionID, ''), @Target = ISNULL(@Target, ''), @DoneBy = ISNULL(@DoneBy, '')
	SELECT  @Target = LTRIM(RTRIM(@Target)), @DoneBy = LTRIM(RTRIM(@DoneBy))
	SELECT  @Target = '%' + @Target + '%', @DoneBy = '%' + @DoneBy + '%'

	CREATE TABLE #LogList (LogID INT, LogDate DATETIME, ActionID INT, OldAction NVARCHAR(MAX), NewAction NVARCHAR(MAX), DoneBy NVARCHAR(100))
	CREATE TABLE #Result (LogID INT, LogDate DATETIME, [Action] VARCHAR(50), [Target] VARCHAR(MAX), DoneBy NVARCHAR(100), IsDetail BIT DEFAULT (1))
	
	DECLARE @ModifyUser TABLE (ID INT PRIMARY KEY, Name NVARCHAR(100)) -- @DoneBy
	INSERT INTO @ModifyUser (ID, Name)
	SELECT UserId AS ID, DisplayName AS Name
	FROM dbo.UserInfo WITH(NOLOCK)
	WHERE DisplayName LIKE @DoneBy

	-- Check user test
	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE UserId = @UserId AND DisplayName LIKE 'starix%')
	BEGIN
		DELETE @ModifyUser WHERE Name LIKE 'starix%'
	END

	DECLARE @Action TABLE (ActionID INT)

	IF EXISTS (SELECT TOP 1 1 FROM @ModifyUser)
	BEGIN
		IF ISNULL(@ActionID, '') <> 'All'
		BEGIN
			INSERT INTO @Action (ActionID)
			SELECT DISTINCT CONVERT(INT, val) FROM dbo.strSplit(@ActionID, ',')
		END
		
		INSERT INTO #LogList (LogID, LogDate, ActionID, OldAction, NewAction, DoneBy)
		SELECT DISTINCT ul.Id, ul.LogDate, ul.LogActionId, uld.OldData, uld.Data, m.Name
		FROM dbo.UserLog_RunSP ul WITH(NOLOCK)
			INNER JOIN dbo.UserLog_RunSP_Detail uld WITH(NOLOCK) ON ul.Id = uld.Id
			INNER JOIN @ModifyUser m ON ul.UserId = m.ID
		WHERE
			(@ActionID = 'All' OR ul.LogActionId IN (SELECT ActionID FROM @Action))
			AND ul.LogDate BETWEEN @FDate AND @TDate
			AND EXISTS (
				SELECT TOP 1 1
				FROM dbo.LogActionType lt WITH(NOLOCK)
					INNER JOIN dbo.LogAction l WITH(NOLOCK) ON lt.LogActionTypeId = l.LogActionTypeId
				WHERE l.[Enable] = 1 AND ul.LogActionId  = l.LogActionId
			) 

		-- Target: Client
		IF EXISTS (SELECT TOP 1 1 FROM dbo.LogAction WITH(NOLOCK) WHERE LogActionTypeId = 1 AND (@ActionID = 'All' OR LogActionId IN (SELECT ActionID FROM @Action)))
		BEGIN
			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], l.LicenseeName, A.DoneBy
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], CONVERT(XML, ISNULL(ISNULL(ll.NewAction, ll.OldAction), N'<r></r>')) AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionTypeId = 1
			) A
				CROSS APPLY A.[Target].nodes('r') d(c)
				INNER JOIN dbo.Licensee l WITH(NOLOCK) ON l.LicenseeId = d.c.value('@lid','INT')
			WHERE l.LicenseeName LIKE @Target

			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], l.LicenseeName, A.DoneBy
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], CONVERT(XML, ISNULL(ISNULL(ll.NewAction, ll.OldAction), N'<r><row /></r>')) AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionTypeId = 1
			) A
				CROSS APPLY A.[Target].nodes('r/row') d(c)
				INNER JOIN dbo.Licensee l WITH(NOLOCK) ON l.LicenseeId = d.c.value('@lid','INT')
			WHERE l.LicenseeName LIKE @Target
		END

		-- Target: Product Name
		IF (@ActionID = 'All' OR EXISTS (SELECT TOP 1 1 FROM @Action WHERE ActionID IN (3003, 3004, 3005, 200)))
		BEGIN
			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], d.c.value('@pn','VARCHAR(100)'), A.DoneBy
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], CONVERT(XML, ISNULL(ISNULL(ll.NewAction, ll.OldAction), N'<r></r>')) AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionId IN (3003, 3004, 3005)
			) A
				CROSS APPLY A.[Target].nodes('r') d(c)
			WHERE d.c.value('@pn','VARCHAR(100)') LIKE @Target

			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], d.c.value('@pn','VARCHAR(100)'), A.DoneBy
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], CONVERT(XML, ISNULL(ISNULL(ll.NewAction, ll.OldAction), N'<r><lp><row /></lp></r>')) AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionId = 200
			) A
				CROSS APPLY A.[Target].nodes('r/lp/row') d(c)
			WHERE d.c.value('@pn','VARCHAR(100)') LIKE @Target
		END
		
		-- Target: Type Of Licensee
		IF (@ActionID = 'All' OR EXISTS (SELECT TOP 1 1 FROM @Action WHERE ActionID IN (3000, 3001, 3002)))
		BEGIN
			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], d.c.value('@ltn','VARCHAR(100)'), A.DoneBy
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], CONVERT(XML, ISNULL(ISNULL(ll.NewAction, ll.OldAction), N'<r></r>')) AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionId IN (3000, 3001, 3002)
			) A
				CROSS APPLY A.[Target].nodes('r') d(c)
			WHERE d.c.value('@ltn','VARCHAR(100)') LIKE @Target
		END
		
		-- Target: Feature
		IF (@ActionID = 'All' OR EXISTS (SELECT TOP 1 1 FROM @Action WHERE ActionID IN (3009, 3010, 3011, 500)))
		BEGIN
			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], d.c.value('@fn','VARCHAR(100)'), A.DoneBy
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], CONVERT(XML, ISNULL(ISNULL(ll.NewAction, ll.OldAction), N'<r></r>')) AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionId IN (3009, 3010, 3011)
			) A
				CROSS APPLY A.[Target].nodes('r') d(c)
			WHERE d.c.value('@fn','VARCHAR(100)') LIKE @Target

			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], d.c.value('@fn','VARCHAR(100)'), A.DoneBy
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], CONVERT(XML, ISNULL(ISNULL(ll.NewAction, ll.OldAction), N'<r><lf><row /></lf></r>')) AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionId = 500
			) A
				CROSS APPLY A.[Target].nodes('r/lf/row') d(c)
			WHERE d.c.value('@fn','VARCHAR(100)') LIKE @Target
		END
		
		-- Target: Category
		IF (@ActionID = 'All' OR EXISTS (SELECT TOP 1 1 FROM @Action WHERE ActionID IN (3006, 3007, 3008)))
		BEGIN
			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], d.c.value('@cn','VARCHAR(100)'), A.DoneBy
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], CONVERT(XML, ISNULL(ISNULL(ll.NewAction, ll.OldAction), N'<r></r>')) AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionId IN (3006, 3007, 3008)
			) A
				CROSS APPLY A.[Target].nodes('r') d(c)
			WHERE d.c.value('@cn','VARCHAR(100)') LIKE @Target
		END
		
		-- Target: User
		IF (@ActionID = 'All' OR EXISTS (SELECT TOP 1 1 FROM @Action WHERE ActionID IN (2000, 2001, 2002, 3012, 3013)))
		BEGIN
			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], d.c.value('@udn','VARCHAR(100)'), A.DoneBy
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], CONVERT(XML, ISNULL(ISNULL(ll.NewAction, ll.OldAction), N'<r></r>')) AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionId IN (2000, 3012)
			) A
				CROSS APPLY A.[Target].nodes('r') d(c)
			WHERE d.c.value('@udn','VARCHAR(100)') LIKE @Target

			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], u.DisplayName, A.DoneBy
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], CONVERT(XML, ISNULL(ISNULL(ll.NewAction, ll.OldAction), N'<r></r>')) AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionId IN (2001, 3013, 3014)
			) A
				CROSS APPLY A.[Target].nodes('r') d(c)
				INNER JOIN dbo.UserInfo u WITH(NOLOCK) ON d.c.value('@uid','VARCHAR(100)') = u.UserId
			WHERE u.DisplayName LIKE @Target

			-- get log update user password from NAP Admin --
			INSERT INTO #LogList (LogID, LogDate, ActionID, OldAction, NewAction, DoneBy)
			SELECT n.Id, n.LogDate, 2002, nd.Data, nd.OldData, m.Name
			FROM bodb_NAPLOG.dbo.NAPLog_RUNSP n WITH(NOLOCK)
				INNER JOIN bodb_NAPLOG.dbo.NAPLOG_RUNSP_Detail nd WITH(NOLOCK) ON n.Id = nd.ID
				INNER JOIN @ModifyUser m ON n.UserId = m.ID
			WHERE n.ActionId = 3 AND n.siteID = 24 -- OIC /*89: local, 24: UAT, PRO*/

			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy, IsDetail)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], u.DisplayName, A.DoneBy, 0
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], CONVERT(XML, ISNULL(ISNULL(ll.NewAction, ll.OldAction), N'<r></r>')) AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionId = 2002
			) A
				CROSS APPLY A.[Target].nodes('r') d(c)
				INNER JOIN dbo.UserInfo u WITH(NOLOCK) ON d.c.value('@ui','VARCHAR(100)') = u.UserId
			WHERE u.DisplayName LIKE @Target
		END
		
		-- Target Notification
		IF (@ActionID = 'All' OR EXISTS (SELECT TOP 1 1 FROM @Action WHERE ActionID IN (4006, 4009)))			
		BEGIN
			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], A.[Target], A.DoneBy
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], 'Notification' AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionId IN (4006, 4009)
			) A			
		END
	END

	SELECT @TotalRecords = COUNT(*) FROM #Result

	-- paging
	DECLARE @rowStart INT, @rowEnd INT
	SELECT  @rowStart = 1 + @PageIndex * @PageSize, @rowEnd = (@PageIndex + 1) * @PageSize
	
	;WITH CTE_Result AS (
		SELECT
			ROW_NUMBER() OVER(ORDER BY LogDate DESC, LogID DESC) AS rownum,
			*
		FROM #Result
	)
	SELECT
		*
	FROM CTE_Result
	WHERE rownum BETWEEN @rowStart AND @rowEnd
	ORDER BY rownum

	DROP TABLE #LogList
	DROP TABLE #Result
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LogListSel_Details]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LogListSel_Details    Script Date: 1/8/2018 10:37:36 PM ******/
CREATE PROCEDURE [dbo].[OIC_LogListSel_Details]
	@ActionID INT
AS
/*
	Creator: Percy
	Date: 2016-10-10
	DB: DBOIC.bodb_OIC
	Task: View detail of log list [RedmineID: #64713]

	Revisions:
		- 20170328@Percy: Add new function: Client List [RemineID: #70323]
		- 20170525@Percy: Implement new request [RedmineID: #70326, #74330, #74879]
		- 20170802@Percy: Support Url testing account [RedmineID: #80712]
		- 20170828@Scofield: Add Reseller [#82144]
		- 20171019@Scofield: Update log for update Amendment Notification [#84004]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Result TABLE (ID TINYINT, Field NVARCHAR(100), OldValue NVARCHAR(MAX), NewValue NVARCHAR(MAX))

	DECLARE @LogActionId INT
	SELECT  @LogActionId = LogActionId FROM dbo.UserLog_RunSP WITH(NOLOCK) WHERE Id = @ActionID

	IF @LogActionId IN (7,8) -- Insert/Update Client
	BEGIN
		DECLARE
			@TypeOfLicensee NVARCHAR(30),
			@Sitename NVARCHAR(100),
			@CompanyName NVARCHAR(100),
			@ClientStatus NVARCHAR(30),
			@SoftLaunch NVARCHAR(10), -- datetime format: mm/dd/yyyy
			@FullLaunch NVARCHAR(10), -- datetime format: mm/dd/yyyy
			@MainUrl NVARCHAR(MAX),
			@BackupUrl NVARCHAR(MAX), -- list of backup link
			@APIUrl NVARCHAR(MAX),
			@ContactName NVARCHAR(100),
			@ContactPosition NVARCHAR(100),
			@ContactDepartment NVARCHAR(100),
			@ContactEmail NVARCHAR(50),
			@ContactMobile NVARCHAR(50),
			@ContactSkype NVARCHAR(50),
			@ContactRemark NVARCHAR(600),
			@OfferedCurrencies NVARCHAR(MAX), -- list of currencies
			@SBOfferedLanguages NVARCHAR(MAX), -- list of sportbook languagues
			@ClientLocation NVARCHAR(50),
			@ClientTargetMarket NVARCHAR(MAX), -- list of target markets
			@CommunicationLanguages NVARCHAR(MAX), -- list of communication languagues
			@UnasService NVARCHAR(100),
			@UnasService_Username NVARCHAR(100),
			@UnasService_Password NVARCHAR(100),
			@MobileService NVARCHAR(100),
			@MobileService_WAP NVARCHAR(MAX),
			@MobileService_Smartphone NVARCHAR(MAX),
			@BAAgreement NVARCHAR(100),
			@BAAgreement_Group NVARCHAR(100),
			@BAAgreement_JoinDate NVARCHAR(100),
			@Affiliate NVARCHAR(100),
			@RestrictedCountry NVARCHAR(MAX), -- list of restricted countries
			@RestrictedCountry_Exception NVARCHAR(2000),
			@Remark NVARCHAR(3000),
			@Products NVARCHAR(MAX), -- list of products
			@Features NVARCHAR(MAX), -- list of features
			@AM NVARCHAR(100),
			@PM NVARCHAR(100),
			@Acc1 NVARCHAR(MAX),
			@AccUrl1 NVARCHAR(MAX),
			@Acc2 NVARCHAR(MAX),
			@AccUrl2 NVARCHAR(MAX),
			@Acc3 NVARCHAR(MAX),
			@AccUrl3 NVARCHAR(MAX),
			@Acc4 NVARCHAR(MAX),
			@AccUrl4 NVARCHAR(MAX),
			@Acc5 NVARCHAR(MAX),
			@AccUrl5 NVARCHAR(MAX),
			@CS NVARCHAR(MAX),
			@TA NVARCHAR(MAX),
			@IsChineseMarketOnly NVARCHAR(MAX),
			@Reseller NVARCHAR(MAX),
			@InternalURL NVARCHAR(MAX),

			@TypeOfLicensee_old NVARCHAR(30),
			@Sitename_old NVARCHAR(100),
			@CompanyName_old NVARCHAR(100),
			@ClientStatus_old NVARCHAR(30),
			@SoftLaunch_old NVARCHAR(10), -- datetime format: mm/dd/yyyy
			@FullLaunch_old NVARCHAR(10), -- datetime format: mm/dd/yyyy
			@MainUrl_old NVARCHAR(MAX),
			@BackupUrl_old NVARCHAR(MAX), -- list of backup link
			@APIUrl_old NVARCHAR(MAX),
			@ContactName_old NVARCHAR(100),
			@ContactPosition_old NVARCHAR(100),
			@ContactDepartment_old NVARCHAR(100),
			@ContactEmail_old NVARCHAR(50),
			@ContactMobile_old NVARCHAR(50),
			@ContactSkype_old NVARCHAR(50),
			@ContactRemark_old NVARCHAR(600),
			@OfferedCurrencies_old NVARCHAR(MAX), -- list of currencies
			@SBOfferedLanguages_old NVARCHAR(MAX), -- list of sportbook languagues
			@ClientLocation_old NVARCHAR(50),
			@ClientTargetMarket_old NVARCHAR(MAX), -- list of target markets
			@CommunicationLanguages_old NVARCHAR(MAX), -- list of communication languagues
			@UnasService_old NVARCHAR(100),
			@UnasService_Username_old NVARCHAR(100),
			@UnasService_Password_old NVARCHAR(100),
			@MobileService_old NVARCHAR(100),
			@MobileService_WAP_old NVARCHAR(MAX),
			@MobileService_Smartphone_old NVARCHAR(MAX),
			@BAAgreement_old NVARCHAR(100),
			@BAAgreement_Group_old NVARCHAR(100),
			@BAAgreement_JoinDate_old NVARCHAR(100),
			@Affiliate_old NVARCHAR(100),
			@RestrictedCountry_old NVARCHAR(MAX), -- list of restricted countries
			@RestrictedCountry_Exception_old NVARCHAR(2000),
			@Remark_old NVARCHAR(3000),
			@Products_old NVARCHAR(MAX), -- list of products
			@Features_old NVARCHAR(MAX), -- list of features
			@AM_old NVARCHAR(100),
			@PM_old NVARCHAR(100),
			@Acc1_old NVARCHAR(MAX),
			@AccUrl1_old NVARCHAR(MAX),
			@Acc2_old NVARCHAR(MAX),
			@AccUrl2_old NVARCHAR(MAX),
			@Acc3_old NVARCHAR(MAX),
			@AccUrl3_old NVARCHAR(MAX),
			@Acc4_old NVARCHAR(MAX),
			@AccUrl4_old NVARCHAR(MAX),
			@Acc5_old NVARCHAR(MAX),
			@AccUrl5_old NVARCHAR(MAX),
			@CS_old NVARCHAR(MAX),
			@TA_old NVARCHAR(MAX),
			@IsChineseMarketOnly_old NVARCHAR(MAX),
			@Reseller_old NVARCHAR(MAX),
			@InternalURL_old NVARCHAR(MAX)

		-- Client Info
		SELECT
			@TypeOfLicensee = d.c.value('@tn', 'NVARCHAR(30)'), -- type of licensee
			@Sitename = d.c.value('@ln', 'NVARCHAR(100)'), -- site name
			@CompanyName = d.c.value('@cn', 'NVARCHAR(100)'), -- company name
			@ClientStatus = d.c.value('@sn', 'NVARCHAR(30)'), -- client status
			@SoftLaunch = d.c.value('@sl', 'DATE'), -- soft launch
			@FullLaunch = d.c.value('@fl', 'DATE'), -- full launch
			@MainUrl = d.c.value('@mu', 'NVARCHAR(MAX)'), -- main domain url
			@APIUrl = d.c.value('@au', 'NVARCHAR(MAX)'), -- api url
			@RestrictedCountry_Exception = d.c.value('@rlr', 'NVARCHAR(2000)'), -- add exception for client country restrict list
			@Remark = d.c.value('@rm', 'NVARCHAR(600)'), -- remark
			@ClientLocation = d.c.value('@lc', 'NVARCHAR(50)'), -- location
			@PM = d.c.value('@pmn', 'NVARCHAR(50)'), -- project manager
			@AM = d.c.value('@amn', 'NVARCHAR(50)'), -- account manager
			@IsChineseMarketOnly = d.c.value('@icm', 'NVARCHAR(1)'),
			@Reseller = d.c.value('@res', 'NVARCHAR(1)'),
			@InternalURL = d.c.value('@iu', 'NVARCHAR(MAX)'),

			@TypeOfLicensee_old = od.c.value('@tn', 'NVARCHAR(30)'), -- type of licensee
			@Sitename_old = od.c.value('@ln', 'NVARCHAR(100)'), -- site name
			@CompanyName_old = od.c.value('@cn', 'NVARCHAR(100)'), -- company name
			@ClientStatus_old = od.c.value('@sn', 'NVARCHAR(30)'), -- client status
			@SoftLaunch_old = od.c.value('@sl', 'DATE'), -- soft launch
			@FullLaunch_old = od.c.value('@fl', 'DATE'), -- full launch
			@MainUrl_old = od.c.value('@mu', 'NVARCHAR(MAX)'), -- main domain url
			@APIUrl_old = od.c.value('@au', 'NVARCHAR(MAX)'), -- api url
			@RestrictedCountry_Exception_old = od.c.value('@rlr', 'NVARCHAR(2000)'), -- add exception for client country restrict list
			@Remark_old = od.c.value('@rm', 'NVARCHAR(600)'), -- remark
			@ClientLocation_old = od.c.value('@lc', 'NVARCHAR(50)'), -- location
			@PM_old = od.c.value('@pmn', 'NVARCHAR(50)'), -- project manager
			@AM_old = od.c.value('@amn', 'NVARCHAR(50)'), -- account manager
			@IsChineseMarketOnly_old = od.c.value('@icm', 'NVARCHAR(1)'),
			@Reseller_old = od.c.value('@res', 'NVARCHAR(1)'),
			@InternalURL_old = od.c.value('@iu', 'NVARCHAR(MAX)')
		FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)

		IF ISNULL(@IsChineseMarketOnly, '0') = '0'
			SELECT @IsChineseMarketOnly = 'Unchecked'
		ELSE
			SELECT @IsChineseMarketOnly = 'Checked'

		IF ISNULL(@IsChineseMarketOnly_old, '0') = '0'
			SELECT @IsChineseMarketOnly_old = 'Unchecked'
		ELSE
			SELECT @IsChineseMarketOnly_old = 'Checked'
			
		IF ISNULL(@Reseller, '0') = '0'
			SELECT @Reseller = 'No'
		ELSE
			SELECT @Reseller = 'Yes'
		
		IF ISNULL(@Reseller_old, '0') = '0'
			SELECT @Reseller_old = 'No'
		ELSE
			SELECT @Reseller_old = 'Yes'

		IF @LogActionId = 7
		BEGIN
			SELECT @IsChineseMarketOnly_old = NULL
			SELECT @Reseller_old = NULL
		END

		-- Backup domain
		;WITH CTE_Url AS
		(
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r/bk/row') AS Data, CONVERT(XML, OldData).query('/r/bk/row') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		)
		, CTE1 AS (
			SELECT
				d.c.value('@lbul', 'NVARCHAR(MAX)') AS Url -- backup domain url
			FROM CTE_Url A
				OUTER APPLY A.Data.nodes('row') d(c)
		)
		, CTE2 AS (
			SELECT
				od.c.value('@lbul', 'NVARCHAR(MAX)') AS Url_old -- backup domain url
			FROM CTE_Url A
				OUTER APPLY A.OldData.nodes('row') od(c) 
		) 
		SELECT	@BackupUrl = (SELECT STUFF((SELECT '<br/>' + Url FROM CTE1 FOR XML PATH('')), 1, 11, '')),
				@BackupUrl_old = (SELECT STUFF((SELECT '<br/>' + Url_old FROM CTE2 FOR XML PATH('')), 1, 11, ''))

		-- Main Contact Info
		SELECT
			@ContactName = d.c.value('@cn', 'NVARCHAR(100)'), -- name
			@ContactPosition = d.c.value('@cp', 'NVARCHAR(100)'), -- position
			@ContactDepartment = d.c.value('@cd', 'NVARCHAR(100)'), -- department
			@ContactEmail = d.c.value('@ce', 'NVARCHAR(50)'), -- email
			@ContactSkype = d.c.value('@cs', 'NVARCHAR(50)'), -- skype
			@ContactMobile = d.c.value('@cpn', 'NVARCHAR(50)'), -- contact number
			@ContactRemark = d.c.value('@crm', 'NVARCHAR(600)'), -- remark

			@ContactName_old = od.c.value('@cn', 'NVARCHAR(100)'), -- name
			@ContactPosition_old = od.c.value('@cp', 'NVARCHAR(100)'), -- position
			@ContactDepartment_old = od.c.value('@cd', 'NVARCHAR(100)'), -- department
			@ContactEmail_old = od.c.value('@ce', 'NVARCHAR(50)'), -- email
			@ContactSkype_old = od.c.value('@cs', 'NVARCHAR(50)'), -- skype
			@ContactMobile_old = od.c.value('@cpn', 'NVARCHAR(50)'), -- contact number
			@ContactRemark_old = od.c.value('@crm', 'NVARCHAR(600)') -- remark
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r/lc/row') AS Data, CONVERT(XML, OldData).query('/r/lc/row') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('row') d(c)
			OUTER APPLY A.OldData.nodes('row') od(c)

		-- Offered Currency
		;WITH CTE_Currency AS (
			SELECT
				d.c.value('@cur', 'NVARCHAR(100)') AS Currency, -- currency name

				od.c.value('@cur', 'NVARCHAR(100)') AS Currency_old -- currency name
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/cr/row') AS Data, CONVERT(XML, OldData).query('/r/cr/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@OfferedCurrencies = (SELECT STUFF((SELECT DISTINCT ', ' + Currency FROM CTE_Currency FOR XML PATH('')), 1, 1, '')),
				@OfferedCurrencies_old = (SELECT STUFF((SELECT DISTINCT ', ' + Currency_old FROM CTE_Currency FOR XML PATH('')), 1, 1, ''))

		-- Sportbook Offered Languages
		;WITH CTE_SBLanguages AS (
			SELECT
				d.c.value('@llnsb', 'NVARCHAR(100)') AS SBLanguage, -- language name

				od.c.value('@llnsb', 'NVARCHAR(100)') AS SBLanguage_old -- language name
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/llsb/row') AS Data, CONVERT(XML, OldData).query('/r/llsb/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@SBOfferedLanguages = (SELECT STUFF((SELECT DISTINCT ', ' + SBLanguage FROM CTE_SBLanguages FOR XML PATH('')), 1, 1, '')),
				@SBOfferedLanguages_old = (SELECT STUFF((SELECT DISTINCT ', ' + SBLanguage_old FROM CTE_SBLanguages FOR XML PATH('')), 1, 1, ''))

		-- Client targeted market
		;WITH CTE_Target AS (
			SELECT
				d.c.value('@tmn', 'NVARCHAR(100)') AS TargetMarket, -- targeted market

				od.c.value('@tmn', 'NVARCHAR(100)') AS TargetMarket_old -- targeted market
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/tm/row') AS Data, CONVERT(XML, OldData).query('/r/tm/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@ClientTargetMarket = (SELECT STUFF((SELECT DISTINCT ', ' + TargetMarket FROM CTE_Target FOR XML PATH('')), 1, 1, '')),
				@ClientTargetMarket_old = (SELECT STUFF((SELECT DISTINCT ', ' + TargetMarket_old FROM CTE_Target FOR XML PATH('')), 1, 1, ''))
		
		-- Preferred communication language
		;WITH CTE_Languages AS (
			SELECT
				d.c.value('@lln', 'NVARCHAR(100)') AS [Language], -- language name

				od.c.value('@lln', 'NVARCHAR(100)') AS Language_old -- language name
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/ll/row') AS Data, CONVERT(XML, OldData).query('/r/ll/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@CommunicationLanguages = (SELECT STUFF((SELECT DISTINCT ', ' + [Language] FROM CTE_Languages FOR XML PATH('')), 1, 1, '')),
				@CommunicationLanguages_old = (SELECT STUFF((SELECT DISTINCT ', ' + Language_old FROM CTE_Languages FOR XML PATH('')), 1, 1, ''))
		
		-- Services
		;WITH CTE_Service AS (
			SELECT
				d.c.value('@lsid', 'NVARCHAR(100)') AS ServiceId, -- service id
				d.c.value('@lsn', 'NVARCHAR(100)') AS ServiceName, -- service name
				d.c.value('@lspid', 'NVARCHAR(100)') AS SubServiceId, -- service-child id
				d.c.value('@lspv', 'NVARCHAR(MAX)') AS SubServiceName, -- service-child name

				od.c.value('@lsid', 'NVARCHAR(100)') AS ServiceId_old, -- service id
				od.c.value('@lsn', 'NVARCHAR(100)') AS ServiceName_old, -- service name
				od.c.value('@lspid', 'NVARCHAR(100)') AS SubServiceId_old, -- service-child id
				od.c.value('@lspv', 'NVARCHAR(MAX)') AS SubServiceName_old  -- service-child name
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/ls/row') AS Data, CONVERT(XML, OldData).query('/r/ls/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@UnasService = (SELECT TOP 1 N'Checked' FROM CTE_Service WHERE ServiceId = 1),
				@UnasService_Username = (SELECT TOP 1 SubServiceName FROM CTE_Service WHERE SubServiceId = 2),
				@UnasService_Password = (SELECT TOP 1 SubServiceName FROM CTE_Service WHERE SubServiceId = 1),
				@MobileService = (SELECT TOP 1 N'Checked' FROM CTE_Service WHERE ServiceId = 2),
				@MobileService_WAP = (SELECT TOP 1 SubServiceName FROM CTE_Service WHERE SubServiceId = 4),
				@MobileService_Smartphone = (SELECT TOP 1 SubServiceName FROM CTE_Service WHERE SubServiceId = 3),
				@BAAgreement = (SELECT TOP 1 N'Checked' FROM CTE_Service WHERE ServiceId = 3),
				@BAAgreement_Group = (SELECT TOP 1 SubServiceName FROM CTE_Service WHERE SubServiceId = 6),
				@BAAgreement_JoinDate = (SELECT TOP 1 SubServiceName FROM CTE_Service WHERE SubServiceId = 5),
				@Affiliate = (SELECT TOP 1 N'Checked' FROM CTE_Service WHERE ServiceId = 4),

				@UnasService_old = (SELECT TOP 1 N'Checked' FROM CTE_Service WHERE ServiceId_old = 1),
				@UnasService_Username_old = (SELECT TOP 1 SubServiceName_old FROM CTE_Service WHERE SubServiceId_old = 2),
				@UnasService_Password_old = (SELECT TOP 1 SubServiceName_old FROM CTE_Service WHERE SubServiceId_old = 1),
				@MobileService_old = (SELECT TOP 1 N'Checked' FROM CTE_Service WHERE ServiceId_old = 2),
				@MobileService_WAP_old = (SELECT TOP 1 SubServiceName_old FROM CTE_Service WHERE SubServiceId_old = 4),
				@MobileService_Smartphone_old = (SELECT TOP 1 SubServiceName_old FROM CTE_Service WHERE SubServiceId_old = 3),
				@BAAgreement_old = (SELECT TOP 1 N'Checked' FROM CTE_Service WHERE ServiceId_old = 3),
				@BAAgreement_Group_old = (SELECT TOP 1 SubServiceName_old FROM CTE_Service WHERE SubServiceId_old = 6),
				@BAAgreement_JoinDate_old = (SELECT TOP 1 SubServiceName_old FROM CTE_Service WHERE SubServiceId_old = 5),
				@Affiliate_old = (SELECT TOP 1 N'Checked' FROM CTE_Service WHERE ServiceId_old = 4)
		
		IF @LogActionId = 8 -- update
		BEGIN
			SELECT	@UnasService = ISNULL(@UnasService, N'Unchecked'),
					@MobileService = ISNULL(@MobileService, N'Unchecked'),
					@BAAgreement = ISNULL(@BAAgreement, N'Unchecked'),
					@Affiliate = ISNULL(@Affiliate, N'Unchecked'),
				
					@UnasService_old = ISNULL(@UnasService_old, N'Unchecked'),
					@MobileService_old = ISNULL(@MobileService_old, N'Unchecked'),
					@BAAgreement_old = ISNULL(@BAAgreement_old, N'Unchecked'),
					@Affiliate_old = ISNULL(@Affiliate_old, N'Unchecked')
		END
		
		-- Client country restrict list
		;WITH CTE_Country AS (
			SELECT
				d.c.value('@rln', 'NVARCHAR(100)') AS Country, -- country name

				od.c.value('@rln', 'NVARCHAR(100)') AS Country_old  -- country name
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/rl/row') AS Data, CONVERT(XML, OldData).query('/r/rl/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@RestrictedCountry = (SELECT STUFF((SELECT DISTINCT ', ' + Country FROM CTE_Country FOR XML PATH('')), 1, 1, '')),
				@RestrictedCountry_old = (SELECT STUFF((SELECT DISTINCT  ', ' + Country_old FROM CTE_Country FOR XML PATH('')), 1, 1, ''))

		-- Products
		;WITH CTE_Product AS (
			SELECT
				d.c.value('@lpn', 'NVARCHAR(100)') AS ProductName, -- product name
				d.c.value('@lpl', 'DATE') AS LaunchDate, -- launch date
				d.c.value('@lpt', 'DATE') AS TerminatedDate, -- termination date
				d.c.value('@lpod', 'INT') AS [Order], -- order

				od.c.value('@lpn', 'NVARCHAR(100)') AS ProductName_old, -- product name
				od.c.value('@lpl', 'DATE') AS LaunchDate_old, -- launch date
				od.c.value('@lpt', 'DATE') AS TerminatedDate_old, -- termination date
				od.c.value('@lpod', 'INT') AS [Order_old] -- order
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/lp/row') AS Data, CONVERT(XML, OldData).query('/r/lp/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@Products = (SELECT STUFF((SELECT '<br/>' + ProductName + CASE WHEN LaunchDate IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate, 101) END + CASE WHEN TerminatedDate IS NULL THEN '' ELSE  ' - ' + CONVERT(VARCHAR(10), TerminatedDate, 101) END FROM (SELECT DISTINCT ProductName, [Order], LaunchDate, TerminatedDate FROM CTE_Product) CTE_Product ORDER BY [Order] FOR XML PATH('')), 1, 11, '')),
				@Products_old = (SELECT STUFF((SELECT '<br/>' + ProductName_old + CASE WHEN LaunchDate_old IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate_old, 101) END + CASE WHEN TerminatedDate_old IS NULL THEN '' ELSE  ' - ' + CONVERT(VARCHAR(10), TerminatedDate_old, 101) END FROM (SELECT DISTINCT ProductName_old, [Order_old], LaunchDate_old, TerminatedDate_old FROM CTE_Product) CTE_Product ORDER BY [Order_old] FOR XML PATH('')), 1, 11, ''))
		
		-- Features
		;WITH CTE_Feature AS (
			SELECT
				d.c.value('@lfid', 'INT') AS FeatureId, -- feature id
				d.c.value('@lfn', 'NVARCHAR(100)') AS FeatureName, -- feature name
				d.c.value('@lfl', 'DATE') AS LaunchDate, -- launch date
				d.c.value('@lft', 'DATE') AS TerminatedDate, -- termination date

				od.c.value('@lfid', 'INT') AS FeatureId_old, -- feature id
				od.c.value('@lfn', 'NVARCHAR(100)') AS FeatureName_old, -- feature name
				od.c.value('@lfl', 'DATE') AS LaunchDate_old, -- launch date
				od.c.value('@lft', 'DATE') AS TerminatedDate_old -- termination date
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/lf/row') AS Data, CONVERT(XML, OldData).query('/r/lf/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@Features = (SELECT STUFF((SELECT '<br/>' + FeatureName + CASE WHEN LaunchDate IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate, 101) END + CASE WHEN TerminatedDate IS NULL THEN '' ELSE  ' - ' + CONVERT(VARCHAR(10), TerminatedDate, 101) END FROM (SELECT DISTINCT FeatureId, FeatureName, LaunchDate, TerminatedDate FROM CTE_Feature) CTE_Feature ORDER BY FeatureId FOR XML PATH('')), 1, 11, '')),
				@Features_old = (SELECT STUFF((SELECT '<br/>' + FeatureName_old + CASE WHEN LaunchDate_old IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate_old, 101) END + CASE WHEN TerminatedDate_old IS NULL THEN '' ELSE  ' - ' + CONVERT(VARCHAR(10), TerminatedDate_old, 101) END FROM (SELECT DISTINCT FeatureId_old, FeatureName_old, LaunchDate_old, TerminatedDate_old FROM CTE_Feature) CTE_Feature ORDER BY FeatureId_old FOR XML PATH('')), 1, 11, ''))

		-- Account Info
		;WITH CTE_Account_Font AS (
			SELECT
				d.c.value('@lan', 'NVARCHAR(100)') AS Username, -- username
				d.c.value('@lap', 'NVARCHAR(100)') AS [Password], -- password
				d.c.value('@lat', 'NVARCHAR(10)') AS [Type], -- type -- 1: Customer front end, 2: Internal backend (OneonOne CS), 3: Internal backend (Training Account)
				d.c.value('@lod', 'NVARCHAR(10)') AS [Order], -- order
				d.c.value('@lu', 'VARCHAR(MAX)') AS Url, -- url

				od.c.value('@lan', 'NVARCHAR(100)') AS Username_old, -- username
				od.c.value('@lap', 'NVARCHAR(100)') AS Password_old, -- password
				od.c.value('@lat', 'NVARCHAR(10)') AS Type_old,  -- type -- 1: Customer front end, 2: Internal backend (OneonOne CS), 3: Internal backend (Training Account)
				od.c.value('@lod', 'NVARCHAR(10)') AS Order_old, -- order
				od.c.value('@lu', 'VARCHAR(MAX)') AS Url_old -- url
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/la/row') AS Data, CONVERT(XML, OldData).query('/r/la/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT
			@Acc1 = CASE WHEN [Type] = N'1' AND [Order] = 1 THEN Username + ' - ' + [Password] ELSE @Acc1 END,
			@Acc2 = CASE WHEN [Type] = N'1' AND [Order] = 2 THEN Username + ' - ' + [Password] ELSE @Acc2 END,
			@Acc3 = CASE WHEN [Type] = N'1' AND [Order] = 3 THEN Username + ' - ' + [Password] ELSE @Acc3 END,
			@Acc4 = CASE WHEN [Type] = N'1' AND [Order] = 4 THEN Username + ' - ' + [Password] ELSE @Acc4 END,
			@Acc5 = CASE WHEN [Type] = N'1' AND [Order] = 5 THEN Username + ' - ' + [Password] ELSE @Acc5 END,

			@Acc1_old = CASE WHEN [Type_old] = N'1' AND [Order_old] = 1 THEN Username_old + ' - ' + [Password_old] ELSE @Acc1_old END,
			@Acc2_old = CASE WHEN [Type_old] = N'1' AND [Order_old] = 2 THEN Username_old + ' - ' + [Password_old] ELSE @Acc2_old END,
			@Acc3_old = CASE WHEN [Type_old] = N'1' AND [Order_old] = 3 THEN Username_old + ' - ' + [Password_old] ELSE @Acc3_old END,
			@Acc4_old = CASE WHEN [Type_old] = N'1' AND [Order_old] = 4 THEN Username_old + ' - ' + [Password_old] ELSE @Acc4_old END,
			@Acc5_old = CASE WHEN [Type_old] = N'1' AND [Order_old] = 5 THEN Username_old + ' - ' + [Password_old] ELSE @Acc5_old END,

			@AccUrl1 = CASE WHEN [Type] = N'1' AND [Order] = 1 THEN Url ELSE @AccUrl1 END,
			@AccUrl2 = CASE WHEN [Type] = N'1' AND [Order] = 2 THEN Url ELSE @AccUrl2 END,
			@AccUrl3 = CASE WHEN [Type] = N'1' AND [Order] = 3 THEN Url ELSE @AccUrl3 END,
			@AccUrl4 = CASE WHEN [Type] = N'1' AND [Order] = 4 THEN Url ELSE @AccUrl4 END,
			@AccUrl5 = CASE WHEN [Type] = N'1' AND [Order] = 5 THEN Url ELSE @AccUrl5 END,

			@AccUrl1_old = CASE WHEN [Type_old] = N'1' AND [Order_old] = 1 THEN Url_old ELSE @AccUrl1_old END,
			@AccUrl2_old = CASE WHEN [Type_old] = N'1' AND [Order_old] = 2 THEN Url_old ELSE @AccUrl2_old END,
			@AccUrl3_old = CASE WHEN [Type_old] = N'1' AND [Order_old] = 3 THEN Url_old ELSE @AccUrl3_old END,
			@AccUrl4_old = CASE WHEN [Type_old] = N'1' AND [Order_old] = 4 THEN Url_old ELSE @AccUrl4_old END,
			@AccUrl5_old = CASE WHEN [Type_old] = N'1' AND [Order_old] = 5 THEN Url_old ELSE @AccUrl5_old END
		FROM CTE_Account_Font

		SELECT
			@Acc1 = ISNULL(@Acc1, ' - '),
			@Acc2 = ISNULL(@Acc2, ' - '),
			@Acc3 = ISNULL(@Acc3, ' - '),
			@Acc4 = ISNULL(@Acc4, ' - '),
			@Acc5 = ISNULL(@Acc5, ' - '),

			@Acc1_old = ISNULL(@Acc1_old, ' - '),
			@Acc2_old = ISNULL(@Acc2_old, ' - '),
			@Acc3_old = ISNULL(@Acc3_old, ' - '),
			@Acc4_old = ISNULL(@Acc4_old, ' - '),
			@Acc5_old = ISNULL(@Acc5_old, ' - '),

			@AccUrl1 = ISNULL(@AccUrl1, ''),
			@AccUrl2 = ISNULL(@AccUrl2, ''),
			@AccUrl3 = ISNULL(@AccUrl3, ''),
			@AccUrl4 = ISNULL(@AccUrl4, ''),
			@AccUrl5 = ISNULL(@AccUrl5, ''),

			@AccUrl1_old = ISNULL(@AccUrl1_old, ''),
			@AccUrl2_old = ISNULL(@AccUrl2_old, ''),
			@AccUrl3_old = ISNULL(@AccUrl3_old, ''),
			@AccUrl4_old = ISNULL(@AccUrl4_old, ''),
			@AccUrl5_old = ISNULL(@AccUrl5_old, '')

		;WITH CTE_Account_End AS (
			SELECT
				d.c.value('@lan', 'NVARCHAR(100)') AS Username, -- username
				d.c.value('@lap', 'NVARCHAR(100)') AS [Password], -- password
				d.c.value('@lat', 'NVARCHAR(10)') AS [Type], -- type -- 1: Customer front end, 2: Internal backend (OneonOne CS), 3: Internal backend (Training Account)
				d.c.value('@lod', 'NVARCHAR(10)') AS [Order], -- order

				od.c.value('@lan', 'NVARCHAR(100)') AS Username_old, -- username
				od.c.value('@lap', 'NVARCHAR(100)') AS Password_old, -- password
				od.c.value('@lat', 'NVARCHAR(10)') AS Type_old,  -- type -- 1: Customer front end, 2: Internal backend (OneonOne CS), 3: Internal backend (Training Account)
				od.c.value('@lod', 'NVARCHAR(10)') AS Order_old -- order
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/la/row') AS Data, CONVERT(XML, OldData).query('/r/la/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
			WHERE
				(  ISNULL(d.c.value('@lat', 'NVARCHAR(10)'), N'') IN (N'2', N'3')
					OR ISNULL(od.c.value('@lat', 'NVARCHAR(10)'), N'') IN (N'2', N'3')
				)
				AND (
					ISNULL(d.c.value('@lan', 'NVARCHAR(100)'), N'') <> ISNULL(od.c.value('@lan', 'NVARCHAR(100)'), N'')
					OR ISNULL(d.c.value('@lap', 'NVARCHAR(100)'), N'') <> ISNULL(od.c.value('@lap', 'NVARCHAR(100)'), N'')
				)
		)
		SELECT	@CS = (SELECT STUFF((SELECT DISTINCT '<br/>' + Username + ' - ' + [Password] FROM CTE_Account_End WHERE [Type] = N'2' FOR XML PATH('')), 1, 11, '')),
				@CS_old = (SELECT STUFF((SELECT DISTINCT '<br/>' + Username_old + ' - ' + Password_old FROM CTE_Account_End WHERE [Type_old] = N'2' FOR XML PATH('')), 1, 11, '')),
				@TA = (SELECT STUFF((SELECT DISTINCT '<br/>' + Username + ' - ' + [Password] FROM CTE_Account_End WHERE [Type] = N'3' FOR XML PATH('')), 1, 11, '')),
				@TA_old = (SELECT STUFF((SELECT DISTINCT '<br/>' + Username_old + ' - ' + Password_old FROM CTE_Account_End WHERE [Type_old] = N'3' FOR XML PATH('')), 1, 11, ''))

		SELECT @CS = ISNULL(@CS, N' - '), @CS_old = ISNULL(@CS_old, N' - '), @TA = ISNULL(@TA, N' - '), @TA_old = ISNULL(@TA_old, N' - ')

		INSERT INTO @Result(ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Type of licensee', @TypeOfLicensee, @TypeOfLicensee_old),
			(2, N'Site name', @Sitename, @Sitename_old),
			(3, N'Company name', @CompanyName, @CompanyName_old),
			(4, N'Client Status', @ClientStatus, @ClientStatus_old),
			(5, N'Chinese Market Only', @IsChineseMarketOnly, @IsChineseMarketOnly_old),
			(6, N'Reseller', @Reseller, @Reseller_old),
			(7, N'Soft Launch', @SoftLaunch, @SoftLaunch_old),
			(8, N'Full Launch', @FullLaunch, @FullLaunch_old),
			(9, N'Main domain URL', @MainUrl, @MainUrl_old),
			(10, N'Backup Domain URL', @BackupUrl, @BackupUrl_old),
			(11, N'API URL', @APIUrl, @APIUrl_old),
			(12, N'Main Contact - Name', @ContactName, @ContactName_old),
			(13, N'Main Contact - Position', @ContactPosition, @ContactPosition_old),
			(14, N'Main Contact - Department', @ContactDepartment, @ContactDepartment_old),
			(15, N'Main Contact - Email', @ContactEmail, @ContactEmail_old),
			(16, N'Main Contact - Mobile Number', @ContactMobile, @ContactMobile_old),
			(17, N'Main Contact - Skype username', @ContactSkype, @ContactSkype_old),
			(18, N'Main Contact - Remark', @ContactRemark, @ContactRemark_old),
			(19, N'Offered currencies', @OfferedCurrencies, @OfferedCurrencies_old),
			(20, N'Sportsbook offered languages', @SBOfferedLanguages, @SBOfferedLanguages_old),
			(21, N'Client Location', @ClientLocation, @ClientLocation_old),
			(22, N'Client targeted market', @ClientTargetMarket, @ClientTargetMarket_old),
			(23, N'Preferred communication language', @CommunicationLanguages, @CommunicationLanguages_old),
			(24, N'Unas service', @UnasService, @UnasService_old),
			(25, N'Unas service - Username', @UnasService_Username, @UnasService_Username_old),
			(26, N'Unas service - Password', @UnasService_Password, @UnasService_Password_old),
			(27, N'Mobile betting service', @MobileService, @MobileService_old),
			(28, N'Mobile betting service - WAP site URL', @MobileService_WAP, @MobileService_WAP_old),
			(29, N'Mobile betting service - Smartphone site URL', @MobileService_Smartphone, @MobileService_Smartphone_old),
			(30, N'BA Agreement', @BAAgreement, @BAAgreement_old),
			(31, N'BA Agreement - Group', @BAAgreement_Group, @BAAgreement_Group_old),
			(32, N'BA Agreement - BA Joined date', @BAAgreement_JoinDate, @BAAgreement_JoinDate_old),
			(33, N'Affiliate Agreement', @Affiliate, @Affiliate_old),
			(34, N'Client country restrict list', @RestrictedCountry, @RestrictedCountry_old),
			(35, N'Add exception for client country restrict list', @RestrictedCountry_Exception, @RestrictedCountry_Exception_old),
			(36, N'Remark', @Remark, @Remark_old),
			(37, N'Products - Launch - Termination', @Products, @Products_old),
			(38, N'Features - Launch - Termination', @Features, @Features_old),
			(39, N'Client Account Manager', @AM, @AM_old),
			(40, N'Client Project Manager', @PM, @PM_old),
			(41, N'Account 1''s URL', @AccUrl1, @AccUrl1_old),
			(42, N'Account 1 (username - password)', @Acc1, @Acc1_old),
			(43, N'Account 2''s URL', @AccUrl2, @AccUrl2_old),
			(44, N'Account 2 (username - password)', @Acc2, @Acc2_old),
			(45, N'Account 3''s URL', @AccUrl3, @AccUrl3_old),
			(46, N'Account 3 (username - password)', @Acc3, @Acc3_old),
			(47, N'Account 4''s URL', @AccUrl4, @AccUrl4_old),
			(48, N'Account 4 (username - password)', @Acc4, @Acc4_old),
			(49, N'Account 5''s URL', @AccUrl5, @AccUrl5_old),
			(50, N'Account 5 (username - password)', @Acc5, @Acc5_old),
			(51, N'Internal backend URL', @InternalURL, @InternalURL_old),
			(52, N'OneonOne CS (username - password)', @CS, @CS_old),
			(53, N'Training Account (username - password)', @TA, @TA_old)			
	END
	ELSE IF @LogActionId IN (100,101,102) -- Insert/Update/Delete Contact
	BEGIN
		DECLARE
			@LicenseeId INT,
			@LicenseeName NVARCHAR(100),
			@Contact_Type NVARCHAR(10),
			@Contact_Name NVARCHAR(100),
			@Contact_Position NVARCHAR(100),
			@Contact_Department NVARCHAR(100),
			@Contact_Email NVARCHAR(50),
			@Contact_Skype NVARCHAR(50),
			@Contact_Mobile NVARCHAR(50),
			@Contact_Landline NVARCHAR(50),
			@Contact_Remark NVARCHAR(600),
			@Contact_Category NVARCHAR(MAX),

			@LicenseeId_old INT,
			@LicenseeName_old NVARCHAR(100),
			@Contact_Type_old NVARCHAR(10),
			@Contact_Name_old NVARCHAR(100),
			@Contact_Position_old NVARCHAR(100),
			@Contact_Department_old NVARCHAR(100),
			@Contact_Email_old NVARCHAR(50),
			@Contact_Skype_old NVARCHAR(50),
			@Contact_Mobile_old NVARCHAR(50),
			@Contact_Landline_old NVARCHAR(50),
			@Contact_Remark_old NVARCHAR(600),
			@Contact_Category_old NVARCHAR(MAX)

		SELECT
			@LicenseeId = d.c.value('@lid', 'INT'), -- client
			@Contact_Type = d.c.value('@lcct', 'NVARCHAR(10)'), -- contact type
			@Contact_Name = d.c.value('@lccn', 'NVARCHAR(100)'), -- contact name
			@Contact_Position = d.c.value('@lcp', 'NVARCHAR(100)'), -- contact position
			@Contact_Department = d.c.value('@lcd', 'NVARCHAR(100)'), -- contact department
			@Contact_Email = d.c.value('@lce', 'NVARCHAR(50)'), -- contact email
			@Contact_Skype = d.c.value('@lcs', 'NVARCHAR(50)'), -- contact skype
			@Contact_Mobile = d.c.value('@lcpn', 'NVARCHAR(50)'), -- contact mobile phone
			@Contact_Landline = d.c.value('@lcll', 'NVARCHAR(50)'), -- contact landline
			@Contact_Remark = d.c.value('@lcr', 'NVARCHAR(600)'), -- contact remark

			@LicenseeId_old = od.c.value('@lid', 'INT'), -- client
			@Contact_Type_old = od.c.value('@lcct', 'NVARCHAR(10)'), -- contact type
			@Contact_Name_old = od.c.value('@lccn', 'NVARCHAR(100)'), -- contact name
			@Contact_Position_old = od.c.value('@lcp', 'NVARCHAR(100)'), -- contact position
			@Contact_Department_old = od.c.value('@lcd', 'NVARCHAR(100)'), -- contact department
			@Contact_Email_old = od.c.value('@lce', 'NVARCHAR(50)'), -- contact email
			@Contact_Skype_old = od.c.value('@lcs', 'NVARCHAR(50)'), -- contact skype
			@Contact_Mobile_old = od.c.value('@lcpn', 'NVARCHAR(50)'), -- contact mobile phone
			@Contact_Landline_old = od.c.value('@lcll', 'NVARCHAR(50)'), -- contact landline
			@Contact_Remark_old = od.c.value('@lcr', 'NVARCHAR(600)') -- contact remark
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)

		;WITH CTE_ContactCategory AS (
			SELECT
				d.c.value('@cn', 'NVARCHAR(100)') AS Category, -- contact category
				d.c.value('@ct', 'TINYINT') AS ContactType, -- contact type

				od.c.value('@cn', 'NVARCHAR(100)') AS Category_old, -- contact category
				od.c.value('@ct', 'TINYINT') AS ContactType_old -- contact type
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/cc/row') AS Data, CONVERT(XML, OldData).query('/r/cc/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@Contact_Category = (SELECT STUFF((SELECT DISTINCT '<br/>' + Category + ' - ' + CASE WHEN ContactType = 0 THEN 'To List' ELSE 'CC List' END FROM CTE_ContactCategory FOR XML PATH('')), 1, 11, '')),
				@Contact_Category_old = (SELECT STUFF((SELECT DISTINCT '<br/>' + Category_old + ' - ' + CASE WHEN ContactType_old = 0 THEN 'To List' ELSE 'CC List' END FROM CTE_ContactCategory FOR XML PATH('')), 1, 11, ''))

		SELECT	@LicenseeName = LicenseeName FROM dbo.Licensee WITH(NOLOCK) WHERE LicenseeId = @LicenseeId
		SELECT	@LicenseeName_old = LicenseeName FROM dbo.Licensee WITH(NOLOCK) WHERE LicenseeId = @LicenseeId_old

		SELECT	@Contact_Type = CASE WHEN @Contact_Type = N'1' THEN N'Group' ELSE N'Individual' END,
				@Contact_Type_old = CASE WHEN @Contact_Type_old = N'1' THEN N'Group' ELSE N'Individual' END
		
		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Site name', @LicenseeName, @LicenseeName_old),
			(2, N'Contact type', @Contact_Type, @Contact_Type_old),
			(3, N'Name', @Contact_Name, @Contact_Name_old),
			(4, N'Position', @Contact_Position, @Contact_Position_old),
			(5, N'Department', @Contact_Department, @Contact_Department_old),
			(6, N'Email address', @Contact_Email, @Contact_Email_old),
			(7, N'Skype username', @Contact_Skype, @Contact_Skype_old),
			(8, N'Mobile number', @Contact_Mobile, @Contact_Mobile_old),
			(9, N'Landline', @Contact_Landline, @Contact_Landline_old),
			(10, N'Remark', @Contact_Remark, @Contact_Remark_old),
			(11, N'Category - List type', @Contact_Category, @Contact_Category_old)
	END
	ELSE IF @LogActionId IN (302,303) -- Insert/Delete Category - Client
	BEGIN
		DECLARE
			@Licensee NVARCHAR(100),
			@Categories NVARCHAR(MAX),

			@Licensee_old NVARCHAR(100),
			@Categories_old NVARCHAR(MAX)

		SELECT
			@Licensee = d.c.value('@ln', 'NVARCHAR(100)'), -- client

			@Licensee_old = od.c.value('@ln', 'NVARCHAR(100)') -- client
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)

		;WITH CTE_ClientCategory AS (
			SELECT
				d.c.value('@cn', 'NVARCHAR(100)') AS Category, -- category

				od.c.value('@cn', 'NVARCHAR(100)') AS Category_old -- category
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/c/row') AS Data, CONVERT(XML, OldData).query('/r/c/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@Categories = (SELECT STUFF((SELECT DISTINCT '<br/>' + Category FROM CTE_ClientCategory FOR XML PATH('')), 1, 11, '')),
				@Categories_old = (SELECT STUFF((SELECT DISTINCT '<br/>' + Category_old FROM CTE_ClientCategory FOR XML PATH('')), 1, 11, ''))

		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Category', @Categories, @Categories_old)
	END
	ELSE IF @LogActionId IN (301) -- Update Category Mailing List
	BEGIN
		DECLARE
			@Category NVARCHAR(100),
			@Contacts NVARCHAR(MAX),

			@Category_old NVARCHAR(100),
			@Contacts_old NVARCHAR(MAX)

		SELECT
			@Category = d.c.value('@cn', 'NVARCHAR(100)'), -- category

			@Category_old = od.c.value('@cn', 'NVARCHAR(100)') -- category
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)

		;WITH CTE_Contact AS (
			SELECT
				d.c.value('@lcc', 'INT') AS ContactId, -- contact id
				d.c.value('@lcn', 'NVARCHAR(100)') AS ContactName, -- contact name
				d.c.value('@lce', 'NVARCHAR(100)') AS ContactEmail, -- contact email
				d.c.value('@cct', 'TINYINT') AS ContactType, -- contact type

				od.c.value('@lcc', 'INT') AS ContactId_old, -- contact id
				od.c.value('@lcn', 'NVARCHAR(100)') AS ContactName_old, -- contact name
				od.c.value('@lce', 'NVARCHAR(100)') AS ContactEmail_old, -- contact email
				od.c.value('@cct', 'TINYINT') AS ContactType_old -- contact type
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/cc/row') AS Data, CONVERT(XML, OldData).query('/r/cc/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@Contacts = (SELECT STUFF((SELECT '<br/>' + ContactName + ' - ' + ContactEmail + ' - ' + CASE WHEN ContactType = 0 THEN 'To List' ELSE 'CC List' END FROM (SELECT DISTINCT ContactId, ContactName, ContactEmail, ContactType FROM CTE_Contact) CTE_Contact ORDER BY ContactId FOR XML PATH('')), 1, 11, '')),
				@Contacts_old = (SELECT STUFF((SELECT '<br/>' + ContactName_old + ' - ' + ContactEmail_old + ' - ' + CASE WHEN ContactType_old = 0 THEN 'To List' ELSE 'CC List' END FROM (SELECT DISTINCT ContactId_old, ContactName_old, ContactEmail_old, ContactType_old FROM CTE_Contact) CTE_Contact ORDER BY ContactId_old FOR XML PATH('')), 1, 11, ''))

		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, @Category, @Contacts, @Contacts_old)
	END
	ELSE IF @LogActionId IN (200) -- Update Client list of a Product
	BEGIN
		DECLARE
			@Product NVARCHAR(100),
			@Product_Clients NVARCHAR(MAX),

			@Product_old NVARCHAR(100),
			@Product_Clients_old NVARCHAR(MAX)

		SELECT
			@Product = d.c.value('@pn', 'NVARCHAR(100)'), -- product

			@Product_old = od.c.value('@pn', 'NVARCHAR(100)') -- product
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)

		;WITH CTE_Product AS (
			SELECT
				d.c.value('@ln', 'NVARCHAR(100)') AS Product, -- client
				d.c.value('@lpld', 'DATE') AS LaunchDate, -- launch date
				d.c.value('@lptd', 'DATE') AS TerminatedDate, -- termination date

				od.c.value('@ln', 'NVARCHAR(100)') AS Product_old, -- client
				od.c.value('@lpld', 'DATE') AS LaunchDate_old, -- launch date
				od.c.value('@lptd', 'DATE') AS TerminatedDate_old -- termination date
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/lp/row') AS Data, CONVERT(XML, OldData).query('/r/lp/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@Product_Clients = (SELECT STUFF((SELECT DISTINCT '<br/>' + Product + CASE WHEN LaunchDate IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate, 101) END + CASE WHEN TerminatedDate IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), TerminatedDate, 101) END FROM CTE_Product WITH(NOLOCK) FOR XML PATH('')), 1, 11, '')),
				@Product_Clients_old = (SELECT STUFF((SELECT DISTINCT '<br/>' + Product_old + CASE WHEN LaunchDate_old IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate_old, 101) END + CASE WHEN TerminatedDate_old IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), TerminatedDate_old, 101) END FROM CTE_Product WITH(NOLOCK) FOR XML PATH('')), 1, 11, ''))

		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Client - Launch - Termination', @Product_Clients, @Product_Clients_old)
	END
	ELSE IF @LogActionId IN (201) -- Update Products for a Client
	BEGIN
		DECLARE
			@Client NVARCHAR(100),
			@Client_Products NVARCHAR(MAX),

			@Client_old NVARCHAR(100),
			@Client_Products_old NVARCHAR(MAX)

		SELECT
			@Client = d.c.value('@ln', 'NVARCHAR(100)'), -- client

			@Client_old = od.c.value('@ln', 'NVARCHAR(100)') -- client
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)

		;WITH CTE_Product AS (
			SELECT
				d.c.value('@pn', 'NVARCHAR(100)') AS Product, -- product
				d.c.value('@pod', 'INT') AS ProductOrder, -- product
				d.c.value('@lld', 'DATE') AS LaunchDate, -- launch date
				d.c.value('@ltd', 'DATE') AS TerminatedDate, -- termination date

				od.c.value('@pn', 'NVARCHAR(100)') AS Product_old, -- product
				od.c.value('@pod', 'INT') AS ProductOrder_old, -- product
				od.c.value('@lld', 'DATE') AS LaunchDate_old, -- launch date
				od.c.value('@ltd', 'DATE') AS TerminatedDate_old -- termination date
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/lp/row') AS Data, CONVERT(XML, OldData).query('/r/lp/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@Client_Products = (SELECT STUFF((SELECT '<br/>' + Product + CASE WHEN LaunchDate IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate, 101) END + CASE WHEN TerminatedDate IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), TerminatedDate, 101) END FROM (SELECT DISTINCT Product, ProductOrder, LaunchDate, TerminatedDate FROM CTE_Product) CTE_Product ORDER BY ProductOrder FOR XML PATH('')), 1, 11, '')),
				@Client_Products_old = (SELECT STUFF((SELECT '<br/>' + Product_old + CASE WHEN LaunchDate_old IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate_old, 101) END + CASE WHEN TerminatedDate_old IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), TerminatedDate_old, 101) END FROM (SELECT DISTINCT Product_old, ProductOrder_old, LaunchDate_old, TerminatedDate_old FROM CTE_Product) CTE_Product ORDER BY ProductOrder_old FOR XML PATH('')), 1, 11, ''))

		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Product - Launch - Termination', @Client_Products, @Client_Products_old)
	END
	ELSE IF @LogActionId IN (500) -- Update Client list of a Feature
	BEGIN
		DECLARE
			@Feature NVARCHAR(100),
			@Feature_Clients NVARCHAR(MAX),

			@Feature_old NVARCHAR(100),
			@Feature_Clients_old NVARCHAR(MAX)

		SELECT
			@Feature = d.c.value('@fn', 'NVARCHAR(100)'), -- feature

			@Feature_old = od.c.value('@fn', 'NVARCHAR(100)') -- feature
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)

		;WITH CTE_Feature AS (
			SELECT
				d.c.value('@ln', 'NVARCHAR(100)') AS Feature, -- client
				d.c.value('@lfld', 'DATE') AS LaunchDate, -- launch date
				d.c.value('@lftd', 'DATE') AS TerminatedDate, -- termination date

				od.c.value('@ln', 'NVARCHAR(100)') AS Feature_old, -- client
				od.c.value('@lfld', 'DATE') AS LaunchDate_old, -- launch date
				od.c.value('@lftd', 'DATE') AS TerminatedDate_old -- termination date
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/lf/row') AS Data, CONVERT(XML, OldData).query('/r/lf/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@Feature_Clients = (SELECT STUFF((SELECT DISTINCT '<br/>' + Feature + CASE WHEN LaunchDate IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate, 101) END + CASE WHEN TerminatedDate IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), TerminatedDate, 101) END FROM CTE_Feature WITH(NOLOCK) FOR XML PATH('')), 1, 11, '')),
				@Feature_Clients_old = (SELECT STUFF((SELECT DISTINCT '<br/>' + Feature_old + CASE WHEN LaunchDate_old IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate_old, 101) END + CASE WHEN TerminatedDate_old IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), TerminatedDate_old, 101) END FROM CTE_Feature WITH(NOLOCK) FOR XML PATH('')), 1, 11, ''))

		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Client - Launch - Termination', @Feature_Clients, @Feature_Clients_old)
	END
	ELSE IF @LogActionId IN (501) -- Update Features for a Client
	BEGIN
		DECLARE
			@Clients NVARCHAR(100),
			@Client_Features NVARCHAR(MAX),

			@Clients_old NVARCHAR(100),
			@Client_Features_old NVARCHAR(MAX)

		SELECT
			@Clients = d.c.value('@ln', 'NVARCHAR(100)'), -- client

			@Clients_old = od.c.value('@ln', 'NVARCHAR(100)') -- client
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)

		;WITH CTE_Feature AS (
			SELECT
				d.c.value('@fn', 'NVARCHAR(100)') AS Feature, -- Feature
				d.c.value('@fid', 'INT') AS FeatureOrder, -- Feature
				d.c.value('@lld', 'DATE') AS LaunchDate, -- launch date
				d.c.value('@ltd', 'DATE') AS TerminatedDate, -- termination date

				od.c.value('@fn', 'NVARCHAR(100)') AS Feature_old, -- Feature
				od.c.value('@fid', 'INT') AS FeatureOrder_old, -- Feature
				od.c.value('@lld', 'DATE') AS LaunchDate_old, -- launch date
				od.c.value('@ltd', 'DATE') AS TerminatedDate_old -- termination date
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/lf/row') AS Data, CONVERT(XML, OldData).query('/r/lf/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@Client_Features = (SELECT STUFF((SELECT '<br/>' + Feature + CASE WHEN LaunchDate IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate, 101) END + CASE WHEN TerminatedDate IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), TerminatedDate, 101) END FROM (SELECT DISTINCT Feature, FeatureOrder, LaunchDate, TerminatedDate FROM CTE_Feature) CTE_Feature ORDER BY FeatureOrder FOR XML PATH('')), 1, 11, '')),
				@Client_Features_old = (SELECT STUFF((SELECT '<br/>' + Feature_old + CASE WHEN LaunchDate_old IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate_old, 101) END + CASE WHEN TerminatedDate_old IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), TerminatedDate_old, 101) END FROM (SELECT DISTINCT Feature_old, FeatureOrder_old, LaunchDate_old, TerminatedDate_old FROM CTE_Feature) CTE_Feature ORDER BY FeatureOrder_old FOR XML PATH('')), 1, 11, ''))

		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Feature - Launch - Termination', @Client_Features, @Client_Features_old)

	END
	ELSE IF @LogActionId IN (400,401,402) -- Insert/Update/Delete Training
	BEGIN
		DECLARE
			@TrainingLicenseeName VARCHAR(50),
			@TrainingStatusName VARCHAR(200),
			@TrainingStatusValue VARCHAR(50),
			@TrainingStatusValue_DateTime DATETIME,
			@TrainingStatusValue_Date VARCHAR(50),
			@TrainingStatusValue_Time VARCHAR(50),
			@Language NVARCHAR(30),
			@Date NVARCHAR(10),
			@StartTime NVARCHAR(20),
			@TimeZone NVARCHAR(10),
			@Attendee NVARCHAR(MAX),

			@TrainingLicenseeName_old VARCHAR(50),
			@TrainingStatusName_old VARCHAR(200),
			@TrainingStatusValue_old VARCHAR(50),
			@TrainingStatusValue_DateTime_old DATETIME,
			@TrainingStatusValue_Date_old VARCHAR(50),
			@TrainingStatusValue_Time_old VARCHAR(50),
			@Language_old NVARCHAR(30),
			@Date_old NVARCHAR(10),
			@StartTime_old NVARCHAR(20),
			@TimeZone_old NVARCHAR(10),
			@Attendee_old NVARCHAR(MAX)

		SELECT
			@TrainingLicenseeName = d.c.value('@ln', 'VARCHAR(50)'), -- licensee
			@TrainingStatusName = d.c.value('@tsn', 'VARCHAR(200)'), -- status
			@TrainingStatusValue = d.c.value('@tsv', 'VARCHAR(50)'), -- status value
			@Language = d.c.value('@lu', 'NVARCHAR(30)'), -- language
			@Date = CONVERT(VARCHAR(10), d.c.value('@td', 'DATE'), 101), -- date
			@StartTime = d.c.value('@td', 'DATETIME'), -- start time
			@TimeZone = d.c.value('@tz', 'NVARCHAR(10)'), -- time zone

			@TrainingLicenseeName_old = od.c.value('@ln', 'VARCHAR(50)'), -- licensee
			@TrainingStatusName_old = od.c.value('@tsn', 'VARCHAR(200)'), -- status
			@TrainingStatusValue_old = od.c.value('@tsv', 'VARCHAR(50)'), -- status value
			@Language_old = od.c.value('@lu', 'NVARCHAR(30)'), -- language
			@Date_old = CONVERT(VARCHAR(10), od.c.value('@td', 'DATE'), 101), -- date
			@StartTime_old = od.c.value('@td', 'DATETIME'), -- start time
			@TimeZone_old = od.c.value('@tz', 'NVARCHAR(10)') -- time zone
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)

		IF ISNULL(@TimeZone, N'') <> N'' AND ISNUMERIC(@TimeZone) = 1
		BEGIN
			SELECT @StartTime = LTRIM(RTRIM(RIGHT(CONVERT(VARCHAR(19), DATEADD(HOUR, CONVERT(INT, @TimeZone), CONVERT(DATETIME, @StartTime)), 100), 7)))
			SELECT @StartTime = LEFT(@StartTime, LEN(@StartTime) - 2) + ' ' + RIGHT(@StartTime, 2)
		END
		
		IF ISNULL(@TimeZone_old, N'') <> N'' AND ISNUMERIC(@TimeZone_old) = 1
		BEGIN
			SELECT @StartTime_old = LTRIM(RTRIM(RIGHT(CONVERT(VARCHAR(19), DATEADD(HOUR, CONVERT(INT, @TimeZone_old), CONVERT(DATETIME, @StartTime_old)), 100), 7)))
			SELECT @StartTime_old = LEFT(@StartTime_old, LEN(@StartTime_old) - 2) + ' ' + RIGHT(@StartTime_old, 2)
		END

		IF ISNULL(@TrainingStatusValue, N'') <> N'' AND ISNUMERIC(@TimeZone) = 1
		BEGIN
			BEGIN TRY
				SELECT @TrainingStatusValue_DateTime = CONVERT(DATETIME, @TrainingStatusValue)
				SELECT @TrainingStatusValue_DateTime = DATEADD(HOUR, CONVERT(INT, @TimeZone), @TrainingStatusValue_DateTime)

				SELECT @TrainingStatusValue_Date = CONVERT(DATE, @TrainingStatusValue_DateTime)

				SELECT @TrainingStatusValue_Time = LTRIM(RTRIM(RIGHT(CONVERT(VARCHAR(19), @TrainingStatusValue_DateTime, 100), 7)))
				SELECT @TrainingStatusValue_Time = LEFT(@TrainingStatusValue_Time, LEN(@TrainingStatusValue_Time) - 2) + ' ' + RIGHT(@TrainingStatusValue_Time, 2)

				
			END TRY
			BEGIN CATCH
				SELECT @TrainingStatusValue_Date = NULL
				SELECT @TrainingStatusValue_Time = NULL
			END CATCH
		END

		IF ISNULL(@TrainingStatusValue_old, N'') <> N'' AND ISNUMERIC(@TimeZone_old) = 1
		BEGIN
			BEGIN TRY
				SELECT @TrainingStatusValue_DateTime_old = CONVERT(DATETIME, @TrainingStatusValue_old)
				SELECT @TrainingStatusValue_DateTime_old = DATEADD(HOUR, CONVERT(INT, @TimeZone_old), @TrainingStatusValue_DateTime_old)

				SELECT @TrainingStatusValue_Date_old = CONVERT(DATE, @TrainingStatusValue_DateTime_old)

				SELECT @TrainingStatusValue_Time_old = LTRIM(RTRIM(RIGHT(CONVERT(VARCHAR(19), @TrainingStatusValue_DateTime_old, 100), 7)))
				SELECT @TrainingStatusValue_Time_old = LEFT(@TrainingStatusValue_Time_old, LEN(@TrainingStatusValue_Time_old) - 2) + ' ' + RIGHT(@TrainingStatusValue_Time_old, 2)

				
			END TRY
			BEGIN CATCH
				SELECT @TrainingStatusValue_Date_old = NULL
				SELECT @TrainingStatusValue_Time_old = NULL
			END CATCH
		END

		IF ISNUMERIC(@TimeZone) = 1
		BEGIN
			IF CONVERT(INT, @TimeZone) < 0
				SELECT @TimeZone = 'GMT' + @TimeZone
			ELSE
				SELECT @TimeZone = 'GMT+' + @TimeZone
		END

		IF ISNUMERIC(@TimeZone_old) = 1
		BEGIN
			IF CONVERT(INT, @TimeZone_old) < 0
				SELECT @TimeZone_old = 'GMT' + @TimeZone_old
			ELSE
				SELECT @TimeZone_old = 'GMT+' + @TimeZone_old
		END

		;WITH CTE_Attendee AS (
			SELECT
				d.c.value('@an', 'NVARCHAR(100)') AS Attendee, -- Attendee
				d.c.value('@ap', 'NVARCHAR(100)') AS Position, -- Position
				d.c.value('@as', 'NVARCHAR(100)') AS Skype, -- Skype

				od.c.value('@an', 'NVARCHAR(100)') AS Attendee_old, -- Attendee
				od.c.value('@ap', 'NVARCHAR(100)') AS Position_old, -- Position
				od.c.value('@as', 'NVARCHAR(100)') AS Skype_old -- Skype
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/a/row') AS Data, CONVERT(XML, OldData).query('/r/a/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@Attendee = (SELECT STUFF((SELECT DISTINCT '<br/>' + Attendee + ' - ' + Position + ' - ' + Skype FROM CTE_Attendee FOR XML PATH('')), 1, 11, '')),
				@Attendee_old = (SELECT STUFF((SELECT DISTINCT '<br/>' + Attendee_old + ' - ' + Position_old + ' - ' + Skype_old FROM CTE_Attendee FOR XML PATH('')), 1, 11, ''))

		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Site name', @TrainingLicenseeName, @TrainingLicenseeName_old),
			(1, N'Language', @Language, @Language_old),
			(2, N'Date', @Date, @Date_old),
			(3, N'Start time', @StartTime, @StartTime_old),
			(4, N'Time zone', @TimeZone, @TimeZone_old),
			(5, N'Attendee - Position - Skype', @Attendee, @Attendee_old),
			(6, N'Status', @TrainingStatusName, @TrainingStatusName_old),
			(7, N'Available Date', @TrainingStatusValue_Date, @TrainingStatusValue_Date_old),
			(8, N'Available Time', @TrainingStatusValue_Time, @TrainingStatusValue_Time_old)
	END
	ELSE IF @LogActionId IN (2000) -- Update User Profile
	BEGIN
		DECLARE
			@User_DisplayName NVARCHAR(100),
			@User_CompanyName NVARCHAR(100),
			@User_PositionName NVARCHAR(100),
			@User_JoinedDate NVARCHAR(100),
			@User_CountryName NVARCHAR(100),
			@User_Email NVARCHAR(100),
			@User_PhoneNumber NVARCHAR(100),
			@User_Skype NVARCHAR(100),
			@User_Line NVARCHAR(100),
			@User_Remark NVARCHAR(100),

			@User_DisplayName_old NVARCHAR(100),
			@User_CompanyName_old NVARCHAR(100),
			@User_PositionName_old NVARCHAR(100),
			@User_JoinedDate_old NVARCHAR(100),
			@User_CountryName_old NVARCHAR(100),
			@User_Email_old NVARCHAR(100),
			@User_PhoneNumber_old NVARCHAR(100),
			@User_Skype_old NVARCHAR(100),
			@User_Line_old NVARCHAR(100),
			@User_Remark_old NVARCHAR(100)

		SELECT
			@User_DisplayName = d.c.value('@udn', 'NVARCHAR(300)'), -- display name
			@User_CompanyName = d.c.value('@ucomn', 'NVARCHAR(300)'), -- company name
			@User_PositionName = d.c.value('@upn', 'NVARCHAR(300)'), -- position
			@User_JoinedDate = d.c.value('@ujd', 'DATE'), -- join date
			@User_CountryName = d.c.value('@ucoun', 'NVARCHAR(300)'), -- country
			@User_Email = d.c.value('@ue', 'NVARCHAR(300)'), -- email
			@User_PhoneNumber = d.c.value('@up', 'NVARCHAR(300)'), -- contact number
			@User_Skype = d.c.value('@us', 'NVARCHAR(300)'), -- skype
			@User_Line = d.c.value('@ul', 'NVARCHAR(300)'), -- line
			@User_Remark = d.c.value('@ur', 'NVARCHAR(300)'), -- remark
			
			@User_DisplayName_old = od.c.value('@udn', 'NVARCHAR(300)'), -- display name
			@User_CompanyName_old = od.c.value('@ucomn', 'NVARCHAR(300)'), -- company name
			@User_PositionName_old = od.c.value('@upn', 'NVARCHAR(300)'), -- position
			@User_JoinedDate_old = od.c.value('@ujd', 'DATE'), -- join date
			@User_CountryName_old = od.c.value('@ucoun', 'NVARCHAR(300)'), -- country
			@User_Email_old = od.c.value('@ue', 'NVARCHAR(300)'), -- email
			@User_PhoneNumber_old = od.c.value('@up', 'NVARCHAR(300)'), -- contact number
			@User_Skype_old = od.c.value('@us', 'NVARCHAR(300)'), -- skype
			@User_Line_old = od.c.value('@ul', 'NVARCHAR(300)'), -- line
			@User_Remark_old = od.c.value('@ur', 'NVARCHAR(300)') -- remark
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)

		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Display name', @User_DisplayName, @User_DisplayName_old),
			(2, N'Company', @User_CompanyName, @User_CompanyName_old),
			(3, N'Position', @User_PositionName, @User_PositionName_old),
			(4, N'Joined date', @User_JoinedDate, @User_JoinedDate_old),
			(5, N'Country base', @User_CountryName, @User_CountryName_old),
			(6, N'Email address', @User_Email, @User_Email_old),
			(7, N'Contact Number', @User_PhoneNumber, @User_PhoneNumber_old),
			(8, N'Skype username', @User_Skype, @User_Skype_old),
			(9, N'Line username', @User_Line, @User_Line_old),
			(10, N'Remark', @User_Remark, @User_Remark_old)
	END
	ELSE IF @LogActionId IN (2001) -- Update Manage Email
	BEGIN
		;WITH CTE_Email AS (
			SELECT
				d.c.value('@lti', 'INT') AS TOLId, -- type of licensee id
				d.c.value('@ltn', 'NVARCHAR(30)') AS TOL, -- type of licensee
				d.c.value('@em', 'NVARCHAR(50)') AS Email, -- email

				od.c.value('@lti', 'INT') AS TOLId_old, -- type of licensee id
				od.c.value('@ltn', 'NVARCHAR(30)') AS TOL_old, -- type of licensee
				od.c.value('@em', 'NVARCHAR(50)') AS Email_old -- email
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/ltm/row') AS Data, CONVERT(XML, OldData).query('/r/ltm/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		), CTE_Email_Result AS (
			SELECT DISTINCT c1.TOLId, c1.TOL, c1.Email, c2.Email_old
			FROM CTE_Email c1
				INNER JOIN CTE_Email c2 ON c1.TOLId = c2.TOLId_old 
		)
		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		SELECT ROW_NUMBER() OVER(ORDER BY TOLId), TOL, Email, Email_old
		FROM CTE_Email_Result

	END
	ELSE IF @LogActionId IN (3000,3001,3002) -- Insert/Update/Delete Type Of Licensee
	BEGIN
		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		SELECT
			1,
			N'Type of licensee',

			d.c.value('@ltn', 'NVARCHAR(300)'), -- type of licensee name

			od.c.value('@ltn', 'NVARCHAR(300)') -- type of licensee name
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)
	END
	ELSE IF @LogActionId IN (3003,3004,3005) -- Insert/Update/Delete Product
	BEGIN
		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		SELECT
			1,
			N'Product',

			d.c.value('@pn', 'NVARCHAR(300)'), -- product name

			od.c.value('@pn', 'NVARCHAR(300)') -- product name
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)
	END
	ELSE IF @LogActionId IN (3009,3010,3011) -- Insert/Update/Delete Feature
	BEGIN
		INSERT INTO @Result (Field, NewValue, OldValue)
		SELECT
			N'Feature',

			d.c.value('@fn', 'NVARCHAR(300)'), -- feature

			od.c.value('@fn', 'NVARCHAR(300)') -- feature
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)
	END
	ELSE IF @LogActionId IN (3006,3007,3008) -- Insert/Update/Delete Category
	BEGIN
		DECLARE
			@Category_EN NVARCHAR(100),
			@Category_CN NVARCHAR(200),

			@Category_EN_old NVARCHAR(100),
			@Category_CN_old NVARCHAR(200)
		
		SELECT
			@Category_EN = d.c.value('@cn', 'NVARCHAR(100)'), -- category english
			@Category_CN = d.c.value('@cncn', 'NVARCHAR(200)'), -- category chinese

			@Category_EN_old = od.c.value('@cn', 'NVARCHAR(100)'), -- category english
			@Category_CN_old = od.c.value('@cncn', 'NVARCHAR(200)') -- category chinese
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)

		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Category (English)', @Category_EN, @Category_EN_old),
			(2, N'Category (Simplified Chinese)', @Category_CN, @Category_CN_old)
	END
	ELSE IF @LogActionId IN (3013) -- Update Assign Type Of Licensee
	BEGIN
		;WITH CTE_TOL AS (
			SELECT
				d.c.value('@ltn', 'NVARCHAR(30)') AS TOL, -- Type Of Licensee
				od.c.value('@ltn', 'NVARCHAR(30)') AS TOL_old -- Type Of Licensee
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r><lt><row /></lt></r>') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r><lt><row /></lt></r>') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/lt/row') AS Data, CONVERT(XML, OldData).query('/r/lt/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		SELECT	1, N'Type of licensee',
				(SELECT STUFF((SELECT DISTINCT '<br/>' + TOL FROM CTE_TOL FOR XML PATH('')), 1, 11, '')),
				(SELECT STUFF((SELECT DISTINCT '<br/>' + TOL_old FROM CTE_TOL FOR XML PATH('')), 1, 11, ''))
	END
	ELSE IF @LogActionId IN (3012) -- Update User Position
	BEGIN
		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		SELECT
			1,
			N'Position',

			d.c.value('@upn', 'NVARCHAR(50)'), -- position

			od.c.value('@upn', 'NVARCHAR(50)') -- position
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)
	END
	ELSE IF @LogActionId IN (3014) -- Update Reminder
	BEGIN
		DECLARE 
				@MessageId INT,

				@Reminder_Date NVARCHAR(18),
				@Reminder_Subject NVARCHAR(600),
				@Reminder_Content NVARCHAR(MAX),
				@Reminder_TypeId INT,
				@Reminder_Type NVARCHAR(100),
				@Reminder_Option NVARCHAR(MAX),

				@Reminder_TypeId_Old INT,
				@Reminder_Type_Old NVARCHAR(100),
				@Reminder_Option_Old NVARCHAR(MAX)

		SELECT
			@MessageId = d.c.value('@mi', 'INT'), -- Message id
			@Reminder_TypeId = d.c.value('@rti', 'TINYINT'), -- reminder type id
			@Reminder_Option = d.c.value('@rtv', 'NVARCHAR(MAX)'), -- reminder type value

			@Reminder_TypeId_Old = od.c.value('@rti', 'TINYINT'), -- reminder type id
			@Reminder_Option_Old = od.c.value('@rtv', 'NVARCHAR(MAX)') -- reminder type value
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)
		
		SELECT
			@Reminder_Date = CONVERT(NVARCHAR(10), CreateTime, 101) + ' ' + RIGHT(CONVERT(NVARCHAR(19), CreateTime, 100), 7),
			@Reminder_Subject = SubjectEn,
			@Reminder_Content = ContentEn
		FROM dbo.Message WITH(NOLOCK)
		WHERE MessageId = @MessageId

		SELECT @Reminder_Type = ReminderTypeName
		FROM dbo.ReminderType WITH(NOLOCK) WHERE ReminderTypeId = @Reminder_TypeId

		SELECT @Reminder_Type_Old = ReminderTypeName
		FROM dbo.ReminderType WITH(NOLOCK) WHERE ReminderTypeId = @Reminder_TypeId_Old
		
		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Date', @Reminder_Date, @Reminder_Date),
			(2, N'Subject', @Reminder_Subject, @Reminder_Subject),
			(3, N'Content', @Reminder_Content, @Reminder_Content),
			(4, N'Reminder Type', @Reminder_Type, @Reminder_Type_Old),
			(5, N'Reminder Options', @Reminder_Option, @Reminder_Option_Old)
	END
	ELSE IF @LogActionId IN (4006) -- Update Amendment Notification
	BEGIN
		DECLARE
			@Status NVARCHAR(100),
			@SubjectEn NVARCHAR(300),
			@SubjectCh NVARCHAR(300),
			@SubjectCs NVARCHAR(300),
			@ContentEn NVARCHAR(MAX),
			@ContentCh NVARCHAR(MAX),
			@ContentCs NVARCHAR(MAX),
			
			@Status_old NVARCHAR(100),
			@SubjectEn_old NVARCHAR(300),
			@SubjectCh_old NVARCHAR(300),
			@SubjectCs_old NVARCHAR(300),
			@ContentEn_old NVARCHAR(MAX),
			@ContentCh_old NVARCHAR(MAX),
			@ContentCs_old NVARCHAR(MAX)

		SELECT
			@Status = d.c.value('@sta', 'NVARCHAR(100)'),
			@SubjectEn = d.c.value('@sen', 'NVARCHAR(300)'),
			@SubjectCh = d.c.value('@sch', 'NVARCHAR(300)'),
			@SubjectCs = d.c.value('@scs', 'NVARCHAR(300)'),
			@ContentEn = d.c.value('@cen', 'NVARCHAR(MAX)'),
			@ContentCh = d.c.value('@cch', 'NVARCHAR(MAX)'),
			@ContentCs = d.c.value('@ccs', 'NVARCHAR(MAX)'),
			
			@Status_old = od.c.value('@sta', 'NVARCHAR(100)'),
			@SubjectEn_old = od.c.value('@sen', 'NVARCHAR(300)'),
			@SubjectCh_old = od.c.value('@sch', 'NVARCHAR(300)'),
			@SubjectCs_old = od.c.value('@scs', 'NVARCHAR(300)'),
			@ContentEn_old = od.c.value('@cen', 'NVARCHAR(MAX)'),
			@ContentCh_old = od.c.value('@cch', 'NVARCHAR(MAX)'),
			@ContentCs_old = od.c.value('@ccs', 'NVARCHAR(MAX)')
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)		

		SELECT @Status = CASE WHEN @Status = '1' THEN 'Active'
							  WHEN @Status = '2' THEN 'Inactive'
							  ELSE 'New' END,
			   @Status_old = CASE WHEN @Status_old = '1' THEN 'Active'
							  WHEN @Status_old = '2' THEN 'Inactive'
							  ELSE 'New' END;	
			  
		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Status', @Status, @Status_old),
			(2, N'Subject (English)', @SubjectEn, @SubjectEn_old),
			(3, N'Subject (Trad. Chinese)', @SubjectCh, @SubjectCh_old),
			(4, N'Subject (Smpl. Chinese)', @SubjectCs, @SubjectCs_old),
			(5, N'Content (English)', @ContentEn, @ContentEn_old),
			(6, N'Content (Trad. Chinese)', @ContentCh, @ContentCh_old),
			(7, N'Content (Smpl. Chinese)', @ContentCs, @ContentCs_old)			
	END
	ELSE IF @LogActionId IN (4009) -- Update Reminder
	BEGIN
		DECLARE
			@ReminderMessageId 		NVARCHAR(300),
			@Subject 		NVARCHAR(300),
			
			@ReminderTypeId INT,
			@ReminderType 	NVARCHAR(50),
			@ReminderOption NVARCHAR(MAX),
			
			@ReminderTypeId_old INT,
			@ReminderType_old 	NVARCHAR(50),
			@ReminderOption_old NVARCHAR(MAX)

		SELECT
			@ReminderMessageId = d.c.value('@mi', 'NVARCHAR(300)'),
			
			@ReminderTypeId = d.c.value('@rti', 'NVARCHAR(50)'),
			@ReminderOption = d.c.value('@rtv', 'NVARCHAR(MAX)'),
			
			@ReminderTypeId_old = od.c.value('@rti', 'NVARCHAR(50)'),
			@ReminderOption_old = od.c.value('@rtv', 'NVARCHAR(MAX)')
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)		

		SELECT @Subject = SubjectEn
		FROM dbo.Message WITH(NOLOCK)
		WHERE MessageId = @ReminderMessageId

		SELECT @ReminderType = ReminderTypeName
		FROM dbo.ReminderType WITH(NOLOCK) WHERE ReminderTypeId = @ReminderTypeId

		SELECT @ReminderType_old = ReminderTypeName
		FROM dbo.ReminderType WITH(NOLOCK) WHERE ReminderTypeId = @ReminderTypeId_old
			  
		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Subject', @Subject, @Subject),
			(2, N'Reminder Type', @ReminderType, @ReminderType_old),
			(3, N'Reminder Options', @ReminderOption, @ReminderOption_old)		
	END
	
	-- return result
	IF @LogActionId NOT IN (101, 401, 3014) -- Update Contact/Training/Reminder
	BEGIN
		DELETE @Result
		WHERE ISNULL(OldValue, N'') = ISNULL(NewValue, N'')
	END

	;WITH CTE_Result AS (
		SELECT
			ROW_NUMBER() OVER(ORDER BY ID) AS rownum,
			*
		FROM @Result
	)
	SELECT
		rownum, Field, OldValue, NewValue
	FROM CTE_Result
	ORDER BY rownum 
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LogListSel_Details_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OIC_LogListSel_Details_xtest]
	@ActionID INT
AS
/*
	Creator: Percy
	Date: 2016-10-10
	DB: DBOIC.bodb_OIC
	Task: View detail of log list [RedmineID: #64713]

	Revisions:
		- 20170328@Percy: Add new function: Client List [RemineID: #70323]
		- 20170525@Percy: Implement new request [RedmineID: #70326, #74330, #74879]
		- 20170802@Percy: Support Url testing account [RedmineID: #80712]
		- 20170828@Scofield: Add Reseller [#82144]
		- 20171019@Scofield: Update log for update Amendment Notification [#84004]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Result TABLE (ID TINYINT, Field NVARCHAR(100), OldValue NVARCHAR(MAX), NewValue NVARCHAR(MAX))

	DECLARE @LogActionId INT
	SELECT  @LogActionId = LogActionId FROM dbo.UserLog_RunSP WITH(NOLOCK) WHERE Id = @ActionID

	IF @LogActionId IN (7,8) -- Insert/Update Client
	BEGIN
		DECLARE
			@TypeOfLicensee NVARCHAR(30),
			@Sitename NVARCHAR(100),
			@CompanyName NVARCHAR(100),
			@ClientStatus NVARCHAR(30),
			@SoftLaunch NVARCHAR(10), -- datetime format: mm/dd/yyyy
			@FullLaunch NVARCHAR(10), -- datetime format: mm/dd/yyyy
			@MainUrl NVARCHAR(MAX),
			@BackupUrl NVARCHAR(MAX), -- list of backup link
			@APIUrl NVARCHAR(MAX),
			@ContactName NVARCHAR(100),
			@ContactPosition NVARCHAR(100),
			@ContactDepartment NVARCHAR(100),
			@ContactEmail NVARCHAR(50),
			@ContactMobile NVARCHAR(50),
			@ContactSkype NVARCHAR(50),
			@ContactRemark NVARCHAR(600),
			@OfferedCurrencies NVARCHAR(MAX), -- list of currencies
			@SBOfferedLanguages NVARCHAR(MAX), -- list of sportbook languagues
			@ClientLocation NVARCHAR(50),
			@ClientTargetMarket NVARCHAR(MAX), -- list of target markets
			@CommunicationLanguages NVARCHAR(MAX), -- list of communication languagues
			@UnasService NVARCHAR(100),
			@UnasService_Username NVARCHAR(100),
			@UnasService_Password NVARCHAR(100),
			@MobileService NVARCHAR(100),
			@MobileService_WAP NVARCHAR(MAX),
			@MobileService_Smartphone NVARCHAR(MAX),
			@BAAgreement NVARCHAR(100),
			@BAAgreement_Group NVARCHAR(100),
			@BAAgreement_JoinDate NVARCHAR(100),
			@Affiliate NVARCHAR(100),
			@RestrictedCountry NVARCHAR(MAX), -- list of restricted countries
			@RestrictedCountry_Exception NVARCHAR(2000),
			@Remark NVARCHAR(3000),
			@Products NVARCHAR(MAX), -- list of products
			@Features NVARCHAR(MAX), -- list of features
			@AM NVARCHAR(100),
			@PM NVARCHAR(100),
			@Acc1 NVARCHAR(MAX),
			@AccUrl1 NVARCHAR(MAX),
			@Acc2 NVARCHAR(MAX),
			@AccUrl2 NVARCHAR(MAX),
			@Acc3 NVARCHAR(MAX),
			@AccUrl3 NVARCHAR(MAX),
			@Acc4 NVARCHAR(MAX),
			@AccUrl4 NVARCHAR(MAX),
			@Acc5 NVARCHAR(MAX),
			@AccUrl5 NVARCHAR(MAX),
			@CS NVARCHAR(MAX),
			@TA NVARCHAR(MAX),
			@IsChineseMarketOnly NVARCHAR(MAX),
			@Reseller NVARCHAR(MAX),
			@InternalURL NVARCHAR(MAX),

			@TypeOfLicensee_old NVARCHAR(30),
			@Sitename_old NVARCHAR(100),
			@CompanyName_old NVARCHAR(100),
			@ClientStatus_old NVARCHAR(30),
			@SoftLaunch_old NVARCHAR(10), -- datetime format: mm/dd/yyyy
			@FullLaunch_old NVARCHAR(10), -- datetime format: mm/dd/yyyy
			@MainUrl_old NVARCHAR(MAX),
			@BackupUrl_old NVARCHAR(MAX), -- list of backup link
			@APIUrl_old NVARCHAR(MAX),
			@ContactName_old NVARCHAR(100),
			@ContactPosition_old NVARCHAR(100),
			@ContactDepartment_old NVARCHAR(100),
			@ContactEmail_old NVARCHAR(50),
			@ContactMobile_old NVARCHAR(50),
			@ContactSkype_old NVARCHAR(50),
			@ContactRemark_old NVARCHAR(600),
			@OfferedCurrencies_old NVARCHAR(MAX), -- list of currencies
			@SBOfferedLanguages_old NVARCHAR(MAX), -- list of sportbook languagues
			@ClientLocation_old NVARCHAR(50),
			@ClientTargetMarket_old NVARCHAR(MAX), -- list of target markets
			@CommunicationLanguages_old NVARCHAR(MAX), -- list of communication languagues
			@UnasService_old NVARCHAR(100),
			@UnasService_Username_old NVARCHAR(100),
			@UnasService_Password_old NVARCHAR(100),
			@MobileService_old NVARCHAR(100),
			@MobileService_WAP_old NVARCHAR(MAX),
			@MobileService_Smartphone_old NVARCHAR(MAX),
			@BAAgreement_old NVARCHAR(100),
			@BAAgreement_Group_old NVARCHAR(100),
			@BAAgreement_JoinDate_old NVARCHAR(100),
			@Affiliate_old NVARCHAR(100),
			@RestrictedCountry_old NVARCHAR(MAX), -- list of restricted countries
			@RestrictedCountry_Exception_old NVARCHAR(2000),
			@Remark_old NVARCHAR(3000),
			@Products_old NVARCHAR(MAX), -- list of products
			@Features_old NVARCHAR(MAX), -- list of features
			@AM_old NVARCHAR(100),
			@PM_old NVARCHAR(100),
			@Acc1_old NVARCHAR(MAX),
			@AccUrl1_old NVARCHAR(MAX),
			@Acc2_old NVARCHAR(MAX),
			@AccUrl2_old NVARCHAR(MAX),
			@Acc3_old NVARCHAR(MAX),
			@AccUrl3_old NVARCHAR(MAX),
			@Acc4_old NVARCHAR(MAX),
			@AccUrl4_old NVARCHAR(MAX),
			@Acc5_old NVARCHAR(MAX),
			@AccUrl5_old NVARCHAR(MAX),
			@CS_old NVARCHAR(MAX),
			@TA_old NVARCHAR(MAX),
			@IsChineseMarketOnly_old NVARCHAR(MAX),
			@Reseller_old NVARCHAR(MAX),
			@InternalURL_old NVARCHAR(MAX)

		-- Client Info
		SELECT
			@TypeOfLicensee = d.c.value('@tn', 'NVARCHAR(30)'), -- type of licensee
			@Sitename = d.c.value('@ln', 'NVARCHAR(100)'), -- site name
			@CompanyName = d.c.value('@cn', 'NVARCHAR(100)'), -- company name
			@ClientStatus = d.c.value('@sn', 'NVARCHAR(30)'), -- client status
			@SoftLaunch = d.c.value('@sl', 'DATE'), -- soft launch
			@FullLaunch = d.c.value('@fl', 'DATE'), -- full launch
			@MainUrl = d.c.value('@mu', 'NVARCHAR(MAX)'), -- main domain url
			@APIUrl = d.c.value('@au', 'NVARCHAR(MAX)'), -- api url
			@RestrictedCountry_Exception = d.c.value('@rlr', 'NVARCHAR(2000)'), -- add exception for client country restrict list
			@Remark = d.c.value('@rm', 'NVARCHAR(600)'), -- remark
			@ClientLocation = d.c.value('@lc', 'NVARCHAR(50)'), -- location
			@PM = d.c.value('@pmn', 'NVARCHAR(50)'), -- project manager
			@AM = d.c.value('@amn', 'NVARCHAR(50)'), -- account manager
			@IsChineseMarketOnly = d.c.value('@icm', 'NVARCHAR(1)'),
			@Reseller = d.c.value('@res', 'NVARCHAR(1)'),
			@InternalURL = d.c.value('@iu', 'NVARCHAR(MAX)'),

			@TypeOfLicensee_old = od.c.value('@tn', 'NVARCHAR(30)'), -- type of licensee
			@Sitename_old = od.c.value('@ln', 'NVARCHAR(100)'), -- site name
			@CompanyName_old = od.c.value('@cn', 'NVARCHAR(100)'), -- company name
			@ClientStatus_old = od.c.value('@sn', 'NVARCHAR(30)'), -- client status
			@SoftLaunch_old = od.c.value('@sl', 'DATE'), -- soft launch
			@FullLaunch_old = od.c.value('@fl', 'DATE'), -- full launch
			@MainUrl_old = od.c.value('@mu', 'NVARCHAR(MAX)'), -- main domain url
			@APIUrl_old = od.c.value('@au', 'NVARCHAR(MAX)'), -- api url
			@RestrictedCountry_Exception_old = od.c.value('@rlr', 'NVARCHAR(2000)'), -- add exception for client country restrict list
			@Remark_old = od.c.value('@rm', 'NVARCHAR(600)'), -- remark
			@ClientLocation_old = od.c.value('@lc', 'NVARCHAR(50)'), -- location
			@PM_old = od.c.value('@pmn', 'NVARCHAR(50)'), -- project manager
			@AM_old = od.c.value('@amn', 'NVARCHAR(50)'), -- account manager
			@IsChineseMarketOnly_old = od.c.value('@icm', 'NVARCHAR(1)'),
			@Reseller_old = od.c.value('@res', 'NVARCHAR(1)'),
			@InternalURL_old = od.c.value('@iu', 'NVARCHAR(MAX)')
		FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)

		IF ISNULL(@IsChineseMarketOnly, '0') = '0'
			SELECT @IsChineseMarketOnly = 'Unchecked'
		ELSE
			SELECT @IsChineseMarketOnly = 'Checked'

		IF ISNULL(@IsChineseMarketOnly_old, '0') = '0'
			SELECT @IsChineseMarketOnly_old = 'Unchecked'
		ELSE
			SELECT @IsChineseMarketOnly_old = 'Checked'
			
		IF ISNULL(@Reseller, '0') = '0'
			SELECT @Reseller = 'No'
		ELSE
			SELECT @Reseller = 'Yes'
		
		IF ISNULL(@Reseller_old, '0') = '0'
			SELECT @Reseller_old = 'No'
		ELSE
			SELECT @Reseller_old = 'Yes'

		IF @LogActionId = 7
		BEGIN
			SELECT @IsChineseMarketOnly_old = NULL
			SELECT @Reseller_old = NULL
		END

		-- Backup domain
		;WITH CTE_Url AS
		(
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r/bk/row') AS Data, CONVERT(XML, OldData).query('/r/bk/row') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		)
		, CTE1 AS (
			SELECT
				d.c.value('@lbul', 'NVARCHAR(MAX)') AS Url -- backup domain url
			FROM CTE_Url A
				OUTER APPLY A.Data.nodes('row') d(c)
		)
		, CTE2 AS (
			SELECT
				od.c.value('@lbul', 'NVARCHAR(MAX)') AS Url_old -- backup domain url
			FROM CTE_Url A
				OUTER APPLY A.OldData.nodes('row') od(c) 
		) 
		SELECT	@BackupUrl = (SELECT STUFF((SELECT '<br/>' + Url FROM CTE1 FOR XML PATH('')), 1, 11, '')),
				@BackupUrl_old = (SELECT STUFF((SELECT '<br/>' + Url_old FROM CTE2 FOR XML PATH('')), 1, 11, ''))

		-- Main Contact Info
		SELECT
			@ContactName = d.c.value('@cn', 'NVARCHAR(100)'), -- name
			@ContactPosition = d.c.value('@cp', 'NVARCHAR(100)'), -- position
			@ContactDepartment = d.c.value('@cd', 'NVARCHAR(100)'), -- department
			@ContactEmail = d.c.value('@ce', 'NVARCHAR(50)'), -- email
			@ContactSkype = d.c.value('@cs', 'NVARCHAR(50)'), -- skype
			@ContactMobile = d.c.value('@cpn', 'NVARCHAR(50)'), -- contact number
			@ContactRemark = d.c.value('@crm', 'NVARCHAR(600)'), -- remark

			@ContactName_old = od.c.value('@cn', 'NVARCHAR(100)'), -- name
			@ContactPosition_old = od.c.value('@cp', 'NVARCHAR(100)'), -- position
			@ContactDepartment_old = od.c.value('@cd', 'NVARCHAR(100)'), -- department
			@ContactEmail_old = od.c.value('@ce', 'NVARCHAR(50)'), -- email
			@ContactSkype_old = od.c.value('@cs', 'NVARCHAR(50)'), -- skype
			@ContactMobile_old = od.c.value('@cpn', 'NVARCHAR(50)'), -- contact number
			@ContactRemark_old = od.c.value('@crm', 'NVARCHAR(600)') -- remark
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r/lc/row') AS Data, CONVERT(XML, OldData).query('/r/lc/row') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('row') d(c)
			OUTER APPLY A.OldData.nodes('row') od(c)

		-- Offered Currency
		;WITH CTE_Currency AS (
			SELECT
				d.c.value('@cur', 'NVARCHAR(100)') AS Currency, -- currency name

				od.c.value('@cur', 'NVARCHAR(100)') AS Currency_old -- currency name
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/cr/row') AS Data, CONVERT(XML, OldData).query('/r/cr/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@OfferedCurrencies = (SELECT STUFF((SELECT DISTINCT ', ' + Currency FROM CTE_Currency FOR XML PATH('')), 1, 1, '')),
				@OfferedCurrencies_old = (SELECT STUFF((SELECT DISTINCT ', ' + Currency_old FROM CTE_Currency FOR XML PATH('')), 1, 1, ''))

		-- Sportbook Offered Languages
		;WITH CTE_SBLanguages AS (
			SELECT
				d.c.value('@llnsb', 'NVARCHAR(100)') AS SBLanguage, -- language name

				od.c.value('@llnsb', 'NVARCHAR(100)') AS SBLanguage_old -- language name
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/llsb/row') AS Data, CONVERT(XML, OldData).query('/r/llsb/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@SBOfferedLanguages = (SELECT STUFF((SELECT DISTINCT ', ' + SBLanguage FROM CTE_SBLanguages FOR XML PATH('')), 1, 1, '')),
				@SBOfferedLanguages_old = (SELECT STUFF((SELECT DISTINCT ', ' + SBLanguage_old FROM CTE_SBLanguages FOR XML PATH('')), 1, 1, ''))

		-- Client targeted market
		;WITH CTE_Target AS (
			SELECT
				d.c.value('@tmn', 'NVARCHAR(100)') AS TargetMarket, -- targeted market

				od.c.value('@tmn', 'NVARCHAR(100)') AS TargetMarket_old -- targeted market
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/tm/row') AS Data, CONVERT(XML, OldData).query('/r/tm/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@ClientTargetMarket = (SELECT STUFF((SELECT DISTINCT ', ' + TargetMarket FROM CTE_Target FOR XML PATH('')), 1, 1, '')),
				@ClientTargetMarket_old = (SELECT STUFF((SELECT DISTINCT ', ' + TargetMarket_old FROM CTE_Target FOR XML PATH('')), 1, 1, ''))
		
		-- Preferred communication language
		;WITH CTE_Languages AS (
			SELECT
				d.c.value('@lln', 'NVARCHAR(100)') AS [Language], -- language name

				od.c.value('@lln', 'NVARCHAR(100)') AS Language_old -- language name
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/ll/row') AS Data, CONVERT(XML, OldData).query('/r/ll/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@CommunicationLanguages = (SELECT STUFF((SELECT DISTINCT ', ' + [Language] FROM CTE_Languages FOR XML PATH('')), 1, 1, '')),
				@CommunicationLanguages_old = (SELECT STUFF((SELECT DISTINCT ', ' + Language_old FROM CTE_Languages FOR XML PATH('')), 1, 1, ''))
		
		-- Services
		;WITH CTE_Service AS (
			SELECT
				d.c.value('@lsid', 'NVARCHAR(100)') AS ServiceId, -- service id
				d.c.value('@lsn', 'NVARCHAR(100)') AS ServiceName, -- service name
				d.c.value('@lspid', 'NVARCHAR(100)') AS SubServiceId, -- service-child id
				d.c.value('@lspv', 'NVARCHAR(MAX)') AS SubServiceName, -- service-child name

				od.c.value('@lsid', 'NVARCHAR(100)') AS ServiceId_old, -- service id
				od.c.value('@lsn', 'NVARCHAR(100)') AS ServiceName_old, -- service name
				od.c.value('@lspid', 'NVARCHAR(100)') AS SubServiceId_old, -- service-child id
				od.c.value('@lspv', 'NVARCHAR(MAX)') AS SubServiceName_old  -- service-child name
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/ls/row') AS Data, CONVERT(XML, OldData).query('/r/ls/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@UnasService = (SELECT TOP 1 N'Checked' FROM CTE_Service WHERE ServiceId = 1),
				@UnasService_Username = (SELECT TOP 1 SubServiceName FROM CTE_Service WHERE SubServiceId = 2),
				@UnasService_Password = (SELECT TOP 1 SubServiceName FROM CTE_Service WHERE SubServiceId = 1),
				@MobileService = (SELECT TOP 1 N'Checked' FROM CTE_Service WHERE ServiceId = 2),
				@MobileService_WAP = (SELECT TOP 1 SubServiceName FROM CTE_Service WHERE SubServiceId = 4),
				@MobileService_Smartphone = (SELECT TOP 1 SubServiceName FROM CTE_Service WHERE SubServiceId = 3),
				@BAAgreement = (SELECT TOP 1 N'Checked' FROM CTE_Service WHERE ServiceId = 3),
				@BAAgreement_Group = (SELECT TOP 1 SubServiceName FROM CTE_Service WHERE SubServiceId = 6),
				@BAAgreement_JoinDate = (SELECT TOP 1 SubServiceName FROM CTE_Service WHERE SubServiceId = 5),
				@Affiliate = (SELECT TOP 1 N'Checked' FROM CTE_Service WHERE ServiceId = 4),

				@UnasService_old = (SELECT TOP 1 N'Checked' FROM CTE_Service WHERE ServiceId_old = 1),
				@UnasService_Username_old = (SELECT TOP 1 SubServiceName_old FROM CTE_Service WHERE SubServiceId_old = 2),
				@UnasService_Password_old = (SELECT TOP 1 SubServiceName_old FROM CTE_Service WHERE SubServiceId_old = 1),
				@MobileService_old = (SELECT TOP 1 N'Checked' FROM CTE_Service WHERE ServiceId_old = 2),
				@MobileService_WAP_old = (SELECT TOP 1 SubServiceName_old FROM CTE_Service WHERE SubServiceId_old = 4),
				@MobileService_Smartphone_old = (SELECT TOP 1 SubServiceName_old FROM CTE_Service WHERE SubServiceId_old = 3),
				@BAAgreement_old = (SELECT TOP 1 N'Checked' FROM CTE_Service WHERE ServiceId_old = 3),
				@BAAgreement_Group_old = (SELECT TOP 1 SubServiceName_old FROM CTE_Service WHERE SubServiceId_old = 6),
				@BAAgreement_JoinDate_old = (SELECT TOP 1 SubServiceName_old FROM CTE_Service WHERE SubServiceId_old = 5),
				@Affiliate_old = (SELECT TOP 1 N'Checked' FROM CTE_Service WHERE ServiceId_old = 4)
		
		IF @LogActionId = 8 -- update
		BEGIN
			SELECT	@UnasService = ISNULL(@UnasService, N'Unchecked'),
					@MobileService = ISNULL(@MobileService, N'Unchecked'),
					@BAAgreement = ISNULL(@BAAgreement, N'Unchecked'),
					@Affiliate = ISNULL(@Affiliate, N'Unchecked'),
				
					@UnasService_old = ISNULL(@UnasService_old, N'Unchecked'),
					@MobileService_old = ISNULL(@MobileService_old, N'Unchecked'),
					@BAAgreement_old = ISNULL(@BAAgreement_old, N'Unchecked'),
					@Affiliate_old = ISNULL(@Affiliate_old, N'Unchecked')
		END
		
		-- Client country restrict list
		;WITH CTE_Country AS (
			SELECT
				d.c.value('@rln', 'NVARCHAR(100)') AS Country, -- country name

				od.c.value('@rln', 'NVARCHAR(100)') AS Country_old  -- country name
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/rl/row') AS Data, CONVERT(XML, OldData).query('/r/rl/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@RestrictedCountry = (SELECT STUFF((SELECT DISTINCT ', ' + Country FROM CTE_Country FOR XML PATH('')), 1, 1, '')),
				@RestrictedCountry_old = (SELECT STUFF((SELECT DISTINCT  ', ' + Country_old FROM CTE_Country FOR XML PATH('')), 1, 1, ''))

		-- Products
		;WITH CTE_Product AS (
			SELECT
				d.c.value('@lpn', 'NVARCHAR(100)') AS ProductName, -- product name
				d.c.value('@lpl', 'DATE') AS LaunchDate, -- launch date
				d.c.value('@lpt', 'DATE') AS TerminatedDate, -- termination date
				d.c.value('@lpod', 'INT') AS [Order], -- order

				od.c.value('@lpn', 'NVARCHAR(100)') AS ProductName_old, -- product name
				od.c.value('@lpl', 'DATE') AS LaunchDate_old, -- launch date
				od.c.value('@lpt', 'DATE') AS TerminatedDate_old, -- termination date
				od.c.value('@lpod', 'INT') AS [Order_old] -- order
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/lp/row') AS Data, CONVERT(XML, OldData).query('/r/lp/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@Products = (SELECT STUFF((SELECT '<br/>' + ProductName + CASE WHEN LaunchDate IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate, 101) END + CASE WHEN TerminatedDate IS NULL THEN '' ELSE  ' - ' + CONVERT(VARCHAR(10), TerminatedDate, 101) END FROM (SELECT DISTINCT ProductName, [Order], LaunchDate, TerminatedDate FROM CTE_Product) CTE_Product ORDER BY [Order] FOR XML PATH('')), 1, 11, '')),
				@Products_old = (SELECT STUFF((SELECT '<br/>' + ProductName_old + CASE WHEN LaunchDate_old IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate_old, 101) END + CASE WHEN TerminatedDate_old IS NULL THEN '' ELSE  ' - ' + CONVERT(VARCHAR(10), TerminatedDate_old, 101) END FROM (SELECT DISTINCT ProductName_old, [Order_old], LaunchDate_old, TerminatedDate_old FROM CTE_Product) CTE_Product ORDER BY [Order_old] FOR XML PATH('')), 1, 11, ''))
		
		-- Features
		;WITH CTE_Feature AS (
			SELECT
				d.c.value('@lfid', 'INT') AS FeatureId, -- feature id
				d.c.value('@lfn', 'NVARCHAR(100)') AS FeatureName, -- feature name
				d.c.value('@lfl', 'DATE') AS LaunchDate, -- launch date
				d.c.value('@lft', 'DATE') AS TerminatedDate, -- termination date

				od.c.value('@lfid', 'INT') AS FeatureId_old, -- feature id
				od.c.value('@lfn', 'NVARCHAR(100)') AS FeatureName_old, -- feature name
				od.c.value('@lfl', 'DATE') AS LaunchDate_old, -- launch date
				od.c.value('@lft', 'DATE') AS TerminatedDate_old -- termination date
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/lf/row') AS Data, CONVERT(XML, OldData).query('/r/lf/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@Features = (SELECT STUFF((SELECT '<br/>' + FeatureName + CASE WHEN LaunchDate IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate, 101) END + CASE WHEN TerminatedDate IS NULL THEN '' ELSE  ' - ' + CONVERT(VARCHAR(10), TerminatedDate, 101) END FROM (SELECT DISTINCT FeatureId, FeatureName, LaunchDate, TerminatedDate FROM CTE_Feature) CTE_Feature ORDER BY FeatureId FOR XML PATH('')), 1, 11, '')),
				@Features_old = (SELECT STUFF((SELECT '<br/>' + FeatureName_old + CASE WHEN LaunchDate_old IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate_old, 101) END + CASE WHEN TerminatedDate_old IS NULL THEN '' ELSE  ' - ' + CONVERT(VARCHAR(10), TerminatedDate_old, 101) END FROM (SELECT DISTINCT FeatureId_old, FeatureName_old, LaunchDate_old, TerminatedDate_old FROM CTE_Feature) CTE_Feature ORDER BY FeatureId_old FOR XML PATH('')), 1, 11, ''))

		-- Account Info
		;WITH CTE_Account_Font AS (
			SELECT
				d.c.value('@lan', 'NVARCHAR(100)') AS Username, -- username
				d.c.value('@lap', 'NVARCHAR(100)') AS [Password], -- password
				d.c.value('@lat', 'NVARCHAR(10)') AS [Type], -- type -- 1: Customer front end, 2: Internal backend (OneonOne CS), 3: Internal backend (Training Account)
				d.c.value('@lod', 'NVARCHAR(10)') AS [Order], -- order
				d.c.value('@lu', 'VARCHAR(MAX)') AS Url, -- url

				od.c.value('@lan', 'NVARCHAR(100)') AS Username_old, -- username
				od.c.value('@lap', 'NVARCHAR(100)') AS Password_old, -- password
				od.c.value('@lat', 'NVARCHAR(10)') AS Type_old,  -- type -- 1: Customer front end, 2: Internal backend (OneonOne CS), 3: Internal backend (Training Account)
				od.c.value('@lod', 'NVARCHAR(10)') AS Order_old, -- order
				od.c.value('@lu', 'VARCHAR(MAX)') AS Url_old -- url
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/la/row') AS Data, CONVERT(XML, OldData).query('/r/la/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT
			@Acc1 = CASE WHEN [Type] = N'1' AND [Order] = 1 THEN Username + ' - ' + [Password] ELSE @Acc1 END,
			@Acc2 = CASE WHEN [Type] = N'1' AND [Order] = 2 THEN Username + ' - ' + [Password] ELSE @Acc2 END,
			@Acc3 = CASE WHEN [Type] = N'1' AND [Order] = 3 THEN Username + ' - ' + [Password] ELSE @Acc3 END,
			@Acc4 = CASE WHEN [Type] = N'1' AND [Order] = 4 THEN Username + ' - ' + [Password] ELSE @Acc4 END,
			@Acc5 = CASE WHEN [Type] = N'1' AND [Order] = 5 THEN Username + ' - ' + [Password] ELSE @Acc5 END,

			@Acc1_old = CASE WHEN [Type_old] = N'1' AND [Order_old] = 1 THEN Username_old + ' - ' + [Password_old] ELSE @Acc1_old END,
			@Acc2_old = CASE WHEN [Type_old] = N'1' AND [Order_old] = 2 THEN Username_old + ' - ' + [Password_old] ELSE @Acc2_old END,
			@Acc3_old = CASE WHEN [Type_old] = N'1' AND [Order_old] = 3 THEN Username_old + ' - ' + [Password_old] ELSE @Acc3_old END,
			@Acc4_old = CASE WHEN [Type_old] = N'1' AND [Order_old] = 4 THEN Username_old + ' - ' + [Password_old] ELSE @Acc4_old END,
			@Acc5_old = CASE WHEN [Type_old] = N'1' AND [Order_old] = 5 THEN Username_old + ' - ' + [Password_old] ELSE @Acc5_old END,

			@AccUrl1 = CASE WHEN [Type] = N'1' AND [Order] = 1 THEN Url ELSE @AccUrl1 END,
			@AccUrl2 = CASE WHEN [Type] = N'1' AND [Order] = 2 THEN Url ELSE @AccUrl2 END,
			@AccUrl3 = CASE WHEN [Type] = N'1' AND [Order] = 3 THEN Url ELSE @AccUrl3 END,
			@AccUrl4 = CASE WHEN [Type] = N'1' AND [Order] = 4 THEN Url ELSE @AccUrl4 END,
			@AccUrl5 = CASE WHEN [Type] = N'1' AND [Order] = 5 THEN Url ELSE @AccUrl5 END,

			@AccUrl1_old = CASE WHEN [Type_old] = N'1' AND [Order_old] = 1 THEN Url_old ELSE @AccUrl1_old END,
			@AccUrl2_old = CASE WHEN [Type_old] = N'1' AND [Order_old] = 2 THEN Url_old ELSE @AccUrl2_old END,
			@AccUrl3_old = CASE WHEN [Type_old] = N'1' AND [Order_old] = 3 THEN Url_old ELSE @AccUrl3_old END,
			@AccUrl4_old = CASE WHEN [Type_old] = N'1' AND [Order_old] = 4 THEN Url_old ELSE @AccUrl4_old END,
			@AccUrl5_old = CASE WHEN [Type_old] = N'1' AND [Order_old] = 5 THEN Url_old ELSE @AccUrl5_old END
		FROM CTE_Account_Font

		SELECT
			@Acc1 = ISNULL(@Acc1, ' - '),
			@Acc2 = ISNULL(@Acc2, ' - '),
			@Acc3 = ISNULL(@Acc3, ' - '),
			@Acc4 = ISNULL(@Acc4, ' - '),
			@Acc5 = ISNULL(@Acc5, ' - '),

			@Acc1_old = ISNULL(@Acc1_old, ' - '),
			@Acc2_old = ISNULL(@Acc2_old, ' - '),
			@Acc3_old = ISNULL(@Acc3_old, ' - '),
			@Acc4_old = ISNULL(@Acc4_old, ' - '),
			@Acc5_old = ISNULL(@Acc5_old, ' - '),

			@AccUrl1 = ISNULL(@AccUrl1, ''),
			@AccUrl2 = ISNULL(@AccUrl2, ''),
			@AccUrl3 = ISNULL(@AccUrl3, ''),
			@AccUrl4 = ISNULL(@AccUrl4, ''),
			@AccUrl5 = ISNULL(@AccUrl5, ''),

			@AccUrl1_old = ISNULL(@AccUrl1_old, ''),
			@AccUrl2_old = ISNULL(@AccUrl2_old, ''),
			@AccUrl3_old = ISNULL(@AccUrl3_old, ''),
			@AccUrl4_old = ISNULL(@AccUrl4_old, ''),
			@AccUrl5_old = ISNULL(@AccUrl5_old, '')

		;WITH CTE_Account_End AS (
			SELECT
				d.c.value('@lan', 'NVARCHAR(100)') AS Username, -- username
				d.c.value('@lap', 'NVARCHAR(100)') AS [Password], -- password
				d.c.value('@lat', 'NVARCHAR(10)') AS [Type], -- type -- 1: Customer front end, 2: Internal backend (OneonOne CS), 3: Internal backend (Training Account)
				d.c.value('@lod', 'NVARCHAR(10)') AS [Order], -- order

				od.c.value('@lan', 'NVARCHAR(100)') AS Username_old, -- username
				od.c.value('@lap', 'NVARCHAR(100)') AS Password_old, -- password
				od.c.value('@lat', 'NVARCHAR(10)') AS Type_old,  -- type -- 1: Customer front end, 2: Internal backend (OneonOne CS), 3: Internal backend (Training Account)
				od.c.value('@lod', 'NVARCHAR(10)') AS Order_old -- order
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/la/row') AS Data, CONVERT(XML, OldData).query('/r/la/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
			WHERE
				(  ISNULL(d.c.value('@lat', 'NVARCHAR(10)'), N'') IN (N'2', N'3')
					OR ISNULL(od.c.value('@lat', 'NVARCHAR(10)'), N'') IN (N'2', N'3')
				)
				AND (
					ISNULL(d.c.value('@lan', 'NVARCHAR(100)'), N'') <> ISNULL(od.c.value('@lan', 'NVARCHAR(100)'), N'')
					OR ISNULL(d.c.value('@lap', 'NVARCHAR(100)'), N'') <> ISNULL(od.c.value('@lap', 'NVARCHAR(100)'), N'')
				)
		)
		SELECT	@CS = (SELECT STUFF((SELECT DISTINCT '<br/>' + Username + ' - ' + [Password] FROM CTE_Account_End WHERE [Type] = N'2' FOR XML PATH('')), 1, 11, '')),
				@CS_old = (SELECT STUFF((SELECT DISTINCT '<br/>' + Username_old + ' - ' + Password_old FROM CTE_Account_End WHERE [Type_old] = N'2' FOR XML PATH('')), 1, 11, '')),
				@TA = (SELECT STUFF((SELECT DISTINCT '<br/>' + Username + ' - ' + [Password] FROM CTE_Account_End WHERE [Type] = N'3' FOR XML PATH('')), 1, 11, '')),
				@TA_old = (SELECT STUFF((SELECT DISTINCT '<br/>' + Username_old + ' - ' + Password_old FROM CTE_Account_End WHERE [Type_old] = N'3' FOR XML PATH('')), 1, 11, ''))

		SELECT @CS = ISNULL(@CS, N' - '), @CS_old = ISNULL(@CS_old, N' - '), @TA = ISNULL(@TA, N' - '), @TA_old = ISNULL(@TA_old, N' - ')

		INSERT INTO @Result(ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Type of licensee', @TypeOfLicensee, @TypeOfLicensee_old),
			(2, N'Site name', @Sitename, @Sitename_old),
			(3, N'Company name', @CompanyName, @CompanyName_old),
			(4, N'Client Status', @ClientStatus, @ClientStatus_old),
			(5, N'Chinese Market Only', @IsChineseMarketOnly, @IsChineseMarketOnly_old),
			(6, N'Reseller', @Reseller, @Reseller_old),
			(7, N'Soft Launch', @SoftLaunch, @SoftLaunch_old),
			(8, N'Full Launch', @FullLaunch, @FullLaunch_old),
			(9, N'Main domain URL', @MainUrl, @MainUrl_old),
			(10, N'Backup Domain URL', @BackupUrl, @BackupUrl_old),
			(11, N'API URL', @APIUrl, @APIUrl_old),
			(12, N'Main Contact - Name', @ContactName, @ContactName_old),
			(13, N'Main Contact - Position', @ContactPosition, @ContactPosition_old),
			(14, N'Main Contact - Department', @ContactDepartment, @ContactDepartment_old),
			(15, N'Main Contact - Email', @ContactEmail, @ContactEmail_old),
			(16, N'Main Contact - Mobile Number', @ContactMobile, @ContactMobile_old),
			(17, N'Main Contact - Skype username', @ContactSkype, @ContactSkype_old),
			(18, N'Main Contact - Remark', @ContactRemark, @ContactRemark_old),
			(19, N'Offered currencies', @OfferedCurrencies, @OfferedCurrencies_old),
			(20, N'Sportsbook offered languages', @SBOfferedLanguages, @SBOfferedLanguages_old),
			(21, N'Client Location', @ClientLocation, @ClientLocation_old),
			(22, N'Client targeted market', @ClientTargetMarket, @ClientTargetMarket_old),
			(23, N'Preferred communication language', @CommunicationLanguages, @CommunicationLanguages_old),
			(24, N'Unas service', @UnasService, @UnasService_old),
			(25, N'Unas service - Username', @UnasService_Username, @UnasService_Username_old),
			(26, N'Unas service - Password', @UnasService_Password, @UnasService_Password_old),
			(27, N'Mobile betting service', @MobileService, @MobileService_old),
			(28, N'Mobile betting service - WAP site URL', @MobileService_WAP, @MobileService_WAP_old),
			(29, N'Mobile betting service - Smartphone site URL', @MobileService_Smartphone, @MobileService_Smartphone_old),
			(30, N'BA Agreement', @BAAgreement, @BAAgreement_old),
			(31, N'BA Agreement - Group', @BAAgreement_Group, @BAAgreement_Group_old),
			(32, N'BA Agreement - BA Joined date', @BAAgreement_JoinDate, @BAAgreement_JoinDate_old),
			(33, N'Affiliate Agreement', @Affiliate, @Affiliate_old),
			(34, N'Client country restrict list', @RestrictedCountry, @RestrictedCountry_old),
			(35, N'Add exception for client country restrict list', @RestrictedCountry_Exception, @RestrictedCountry_Exception_old),
			(36, N'Remark', @Remark, @Remark_old),
			(37, N'Products - Launch - Termination', @Products, @Products_old),
			(38, N'Features - Launch - Termination', @Features, @Features_old),
			(39, N'Client Account Manager', @AM, @AM_old),
			(40, N'Client Project Manager', @PM, @PM_old),
			(41, N'Account 1''s URL', @AccUrl1, @AccUrl1_old),
			(42, N'Account 1 (username - password)', @Acc1, @Acc1_old),
			(43, N'Account 2''s URL', @AccUrl2, @AccUrl2_old),
			(44, N'Account 2 (username - password)', @Acc2, @Acc2_old),
			(45, N'Account 3''s URL', @AccUrl3, @AccUrl3_old),
			(46, N'Account 3 (username - password)', @Acc3, @Acc3_old),
			(47, N'Account 4''s URL', @AccUrl4, @AccUrl4_old),
			(48, N'Account 4 (username - password)', @Acc4, @Acc4_old),
			(49, N'Account 5''s URL', @AccUrl5, @AccUrl5_old),
			(50, N'Account 5 (username - password)', @Acc5, @Acc5_old),
			(51, N'Internal backend URL', @InternalURL, @InternalURL_old),
			(52, N'OneonOne CS (username - password)', @CS, @CS_old),
			(53, N'Training Account (username - password)', @TA, @TA_old)			
	END
	ELSE IF @LogActionId IN (100,101,102) -- Insert/Update/Delete Contact
	BEGIN
		DECLARE
			@LicenseeId INT,
			@LicenseeName NVARCHAR(100),
			@Contact_Type NVARCHAR(10),
			@Contact_Name NVARCHAR(100),
			@Contact_Position NVARCHAR(100),
			@Contact_Department NVARCHAR(100),
			@Contact_Email NVARCHAR(50),
			@Contact_Skype NVARCHAR(50),
			@Contact_Mobile NVARCHAR(50),
			@Contact_Landline NVARCHAR(50),
			@Contact_Remark NVARCHAR(600),
			@Contact_Category NVARCHAR(MAX),

			@LicenseeId_old INT,
			@LicenseeName_old NVARCHAR(100),
			@Contact_Type_old NVARCHAR(10),
			@Contact_Name_old NVARCHAR(100),
			@Contact_Position_old NVARCHAR(100),
			@Contact_Department_old NVARCHAR(100),
			@Contact_Email_old NVARCHAR(50),
			@Contact_Skype_old NVARCHAR(50),
			@Contact_Mobile_old NVARCHAR(50),
			@Contact_Landline_old NVARCHAR(50),
			@Contact_Remark_old NVARCHAR(600),
			@Contact_Category_old NVARCHAR(MAX)

		SELECT
			@LicenseeId = d.c.value('@lid', 'INT'), -- client
			@Contact_Type = d.c.value('@lcct', 'NVARCHAR(10)'), -- contact type
			@Contact_Name = d.c.value('@lccn', 'NVARCHAR(100)'), -- contact name
			@Contact_Position = d.c.value('@lcp', 'NVARCHAR(100)'), -- contact position
			@Contact_Department = d.c.value('@lcd', 'NVARCHAR(100)'), -- contact department
			@Contact_Email = d.c.value('@lce', 'NVARCHAR(50)'), -- contact email
			@Contact_Skype = d.c.value('@lcs', 'NVARCHAR(50)'), -- contact skype
			@Contact_Mobile = d.c.value('@lcpn', 'NVARCHAR(50)'), -- contact mobile phone
			@Contact_Landline = d.c.value('@lcll', 'NVARCHAR(50)'), -- contact landline
			@Contact_Remark = d.c.value('@lcr', 'NVARCHAR(600)'), -- contact remark

			@LicenseeId_old = od.c.value('@lid', 'INT'), -- client
			@Contact_Type_old = od.c.value('@lcct', 'NVARCHAR(10)'), -- contact type
			@Contact_Name_old = od.c.value('@lccn', 'NVARCHAR(100)'), -- contact name
			@Contact_Position_old = od.c.value('@lcp', 'NVARCHAR(100)'), -- contact position
			@Contact_Department_old = od.c.value('@lcd', 'NVARCHAR(100)'), -- contact department
			@Contact_Email_old = od.c.value('@lce', 'NVARCHAR(50)'), -- contact email
			@Contact_Skype_old = od.c.value('@lcs', 'NVARCHAR(50)'), -- contact skype
			@Contact_Mobile_old = od.c.value('@lcpn', 'NVARCHAR(50)'), -- contact mobile phone
			@Contact_Landline_old = od.c.value('@lcll', 'NVARCHAR(50)'), -- contact landline
			@Contact_Remark_old = od.c.value('@lcr', 'NVARCHAR(600)') -- contact remark
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)

		;WITH CTE_ContactCategory AS (
			SELECT
				d.c.value('@cn', 'NVARCHAR(100)') AS Category, -- contact category
				d.c.value('@ct', 'TINYINT') AS ContactType, -- contact type

				od.c.value('@cn', 'NVARCHAR(100)') AS Category_old, -- contact category
				od.c.value('@ct', 'TINYINT') AS ContactType_old -- contact type
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/cc/row') AS Data, CONVERT(XML, OldData).query('/r/cc/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@Contact_Category = (SELECT STUFF((SELECT DISTINCT '<br/>' + Category + ' - ' + CASE WHEN ContactType = 0 THEN 'To List' ELSE 'CC List' END FROM CTE_ContactCategory FOR XML PATH('')), 1, 11, '')),
				@Contact_Category_old = (SELECT STUFF((SELECT DISTINCT '<br/>' + Category_old + ' - ' + CASE WHEN ContactType_old = 0 THEN 'To List' ELSE 'CC List' END FROM CTE_ContactCategory FOR XML PATH('')), 1, 11, ''))

		SELECT	@LicenseeName = LicenseeName FROM dbo.Licensee WITH(NOLOCK) WHERE LicenseeId = @LicenseeId
		SELECT	@LicenseeName_old = LicenseeName FROM dbo.Licensee WITH(NOLOCK) WHERE LicenseeId = @LicenseeId_old

		SELECT	@Contact_Type = CASE WHEN @Contact_Type = N'1' THEN N'Group' ELSE N'Individual' END,
				@Contact_Type_old = CASE WHEN @Contact_Type_old = N'1' THEN N'Group' ELSE N'Individual' END
		
		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Site name', @LicenseeName, @LicenseeName_old),
			(2, N'Contact type', @Contact_Type, @Contact_Type_old),
			(3, N'Name', @Contact_Name, @Contact_Name_old),
			(4, N'Position', @Contact_Position, @Contact_Position_old),
			(5, N'Department', @Contact_Department, @Contact_Department_old),
			(6, N'Email address', @Contact_Email, @Contact_Email_old),
			(7, N'Skype username', @Contact_Skype, @Contact_Skype_old),
			(8, N'Mobile number', @Contact_Mobile, @Contact_Mobile_old),
			(9, N'Landline', @Contact_Landline, @Contact_Landline_old),
			(10, N'Remark', @Contact_Remark, @Contact_Remark_old),
			(11, N'Category - List type', @Contact_Category, @Contact_Category_old)
	END
	ELSE IF @LogActionId IN (302,303) -- Insert/Delete Category - Client
	BEGIN
		DECLARE
			@Licensee NVARCHAR(100),
			@Categories NVARCHAR(MAX),

			@Licensee_old NVARCHAR(100),
			@Categories_old NVARCHAR(MAX)

		SELECT
			@Licensee = d.c.value('@ln', 'NVARCHAR(100)'), -- client

			@Licensee_old = od.c.value('@ln', 'NVARCHAR(100)') -- client
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)

		;WITH CTE_ClientCategory AS (
			SELECT
				d.c.value('@cn', 'NVARCHAR(100)') AS Category, -- category

				od.c.value('@cn', 'NVARCHAR(100)') AS Category_old -- category
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/c/row') AS Data, CONVERT(XML, OldData).query('/r/c/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@Categories = (SELECT STUFF((SELECT DISTINCT '<br/>' + Category FROM CTE_ClientCategory FOR XML PATH('')), 1, 11, '')),
				@Categories_old = (SELECT STUFF((SELECT DISTINCT '<br/>' + Category_old FROM CTE_ClientCategory FOR XML PATH('')), 1, 11, ''))

		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Category', @Categories, @Categories_old)
	END
	ELSE IF @LogActionId IN (301) -- Update Category Mailing List
	BEGIN
		DECLARE
			@Category NVARCHAR(100),
			@Contacts NVARCHAR(MAX),

			@Category_old NVARCHAR(100),
			@Contacts_old NVARCHAR(MAX)

		SELECT
			@Category = d.c.value('@cn', 'NVARCHAR(100)'), -- category

			@Category_old = od.c.value('@cn', 'NVARCHAR(100)') -- category
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)

		;WITH CTE_Contact AS (
			SELECT
				d.c.value('@lcc', 'INT') AS ContactId, -- contact id
				d.c.value('@lcn', 'NVARCHAR(100)') AS ContactName, -- contact name
				d.c.value('@lce', 'NVARCHAR(100)') AS ContactEmail, -- contact email
				d.c.value('@cct', 'TINYINT') AS ContactType, -- contact type

				od.c.value('@lcc', 'INT') AS ContactId_old, -- contact id
				od.c.value('@lcn', 'NVARCHAR(100)') AS ContactName_old, -- contact name
				od.c.value('@lce', 'NVARCHAR(100)') AS ContactEmail_old, -- contact email
				od.c.value('@cct', 'TINYINT') AS ContactType_old -- contact type
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/cc/row') AS Data, CONVERT(XML, OldData).query('/r/cc/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@Contacts = (SELECT STUFF((SELECT '<br/>' + ContactName + ' - ' + ContactEmail + ' - ' + CASE WHEN ContactType = 0 THEN 'To List' ELSE 'CC List' END FROM (SELECT DISTINCT ContactId, ContactName, ContactEmail, ContactType FROM CTE_Contact) CTE_Contact ORDER BY ContactId FOR XML PATH('')), 1, 11, '')),
				@Contacts_old = (SELECT STUFF((SELECT '<br/>' + ContactName_old + ' - ' + ContactEmail_old + ' - ' + CASE WHEN ContactType_old = 0 THEN 'To List' ELSE 'CC List' END FROM (SELECT DISTINCT ContactId_old, ContactName_old, ContactEmail_old, ContactType_old FROM CTE_Contact) CTE_Contact ORDER BY ContactId_old FOR XML PATH('')), 1, 11, ''))

		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, @Category, @Contacts, @Contacts_old)
	END
	ELSE IF @LogActionId IN (200) -- Update Client list of a Product
	BEGIN
		DECLARE
			@Product NVARCHAR(100),
			@Product_Clients NVARCHAR(MAX),

			@Product_old NVARCHAR(100),
			@Product_Clients_old NVARCHAR(MAX)

		SELECT
			@Product = d.c.value('@pn', 'NVARCHAR(100)'), -- product

			@Product_old = od.c.value('@pn', 'NVARCHAR(100)') -- product
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)

		;WITH CTE_Product AS (
			SELECT
				d.c.value('@ln', 'NVARCHAR(100)') AS Product, -- client
				d.c.value('@lpld', 'DATE') AS LaunchDate, -- launch date
				d.c.value('@lptd', 'DATE') AS TerminatedDate, -- termination date

				od.c.value('@ln', 'NVARCHAR(100)') AS Product_old, -- client
				od.c.value('@lpld', 'DATE') AS LaunchDate_old, -- launch date
				od.c.value('@lptd', 'DATE') AS TerminatedDate_old -- termination date
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/lp/row') AS Data, CONVERT(XML, OldData).query('/r/lp/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@Product_Clients = (SELECT STUFF((SELECT DISTINCT '<br/>' + Product + CASE WHEN LaunchDate IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate, 101) END + CASE WHEN TerminatedDate IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), TerminatedDate, 101) END FROM CTE_Product WITH(NOLOCK) FOR XML PATH('')), 1, 11, '')),
				@Product_Clients_old = (SELECT STUFF((SELECT DISTINCT '<br/>' + Product_old + CASE WHEN LaunchDate_old IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate_old, 101) END + CASE WHEN TerminatedDate_old IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), TerminatedDate_old, 101) END FROM CTE_Product WITH(NOLOCK) FOR XML PATH('')), 1, 11, ''))

		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Client - Launch - Termination', @Product_Clients, @Product_Clients_old)
	END
	ELSE IF @LogActionId IN (201) -- Update Products for a Client
	BEGIN
		DECLARE
			@Client NVARCHAR(100),
			@Client_Products NVARCHAR(MAX),

			@Client_old NVARCHAR(100),
			@Client_Products_old NVARCHAR(MAX)

		SELECT
			@Client = d.c.value('@ln', 'NVARCHAR(100)'), -- client

			@Client_old = od.c.value('@ln', 'NVARCHAR(100)') -- client
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)

		;WITH CTE_Product AS (
			SELECT
				d.c.value('@pn', 'NVARCHAR(100)') AS Product, -- product
				d.c.value('@pod', 'INT') AS ProductOrder, -- product
				d.c.value('@lld', 'DATE') AS LaunchDate, -- launch date
				d.c.value('@ltd', 'DATE') AS TerminatedDate, -- termination date

				od.c.value('@pn', 'NVARCHAR(100)') AS Product_old, -- product
				od.c.value('@pod', 'INT') AS ProductOrder_old, -- product
				od.c.value('@lld', 'DATE') AS LaunchDate_old, -- launch date
				od.c.value('@ltd', 'DATE') AS TerminatedDate_old -- termination date
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/lp/row') AS Data, CONVERT(XML, OldData).query('/r/lp/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@Client_Products = (SELECT STUFF((SELECT '<br/>' + Product + CASE WHEN LaunchDate IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate, 101) END + CASE WHEN TerminatedDate IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), TerminatedDate, 101) END FROM (SELECT DISTINCT Product, ProductOrder, LaunchDate, TerminatedDate FROM CTE_Product) CTE_Product ORDER BY ProductOrder FOR XML PATH('')), 1, 11, '')),
				@Client_Products_old = (SELECT STUFF((SELECT '<br/>' + Product_old + CASE WHEN LaunchDate_old IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate_old, 101) END + CASE WHEN TerminatedDate_old IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), TerminatedDate_old, 101) END FROM (SELECT DISTINCT Product_old, ProductOrder_old, LaunchDate_old, TerminatedDate_old FROM CTE_Product) CTE_Product ORDER BY ProductOrder_old FOR XML PATH('')), 1, 11, ''))

		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Product - Launch - Termination', @Client_Products, @Client_Products_old)
	END
	ELSE IF @LogActionId IN (500) -- Update Client list of a Feature
	BEGIN
		DECLARE
			@Feature NVARCHAR(100),
			@Feature_Clients NVARCHAR(MAX),

			@Feature_old NVARCHAR(100),
			@Feature_Clients_old NVARCHAR(MAX)

		SELECT
			@Feature = d.c.value('@fn', 'NVARCHAR(100)'), -- feature

			@Feature_old = od.c.value('@fn', 'NVARCHAR(100)') -- feature
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)

		;WITH CTE_Feature AS (
			SELECT
				d.c.value('@ln', 'NVARCHAR(100)') AS Feature, -- client
				d.c.value('@lfld', 'DATE') AS LaunchDate, -- launch date
				d.c.value('@lftd', 'DATE') AS TerminatedDate, -- termination date

				od.c.value('@ln', 'NVARCHAR(100)') AS Feature_old, -- client
				od.c.value('@lfld', 'DATE') AS LaunchDate_old, -- launch date
				od.c.value('@lftd', 'DATE') AS TerminatedDate_old -- termination date
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/lf/row') AS Data, CONVERT(XML, OldData).query('/r/lf/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@Feature_Clients = (SELECT STUFF((SELECT DISTINCT '<br/>' + Feature + CASE WHEN LaunchDate IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate, 101) END + CASE WHEN TerminatedDate IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), TerminatedDate, 101) END FROM CTE_Feature WITH(NOLOCK) FOR XML PATH('')), 1, 11, '')),
				@Feature_Clients_old = (SELECT STUFF((SELECT DISTINCT '<br/>' + Feature_old + CASE WHEN LaunchDate_old IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate_old, 101) END + CASE WHEN TerminatedDate_old IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), TerminatedDate_old, 101) END FROM CTE_Feature WITH(NOLOCK) FOR XML PATH('')), 1, 11, ''))

		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Client - Launch - Termination', @Feature_Clients, @Feature_Clients_old)
	END
	ELSE IF @LogActionId IN (501) -- Update Features for a Client
	BEGIN
		DECLARE
			@Clients NVARCHAR(100),
			@Client_Features NVARCHAR(MAX),

			@Clients_old NVARCHAR(100),
			@Client_Features_old NVARCHAR(MAX)

		SELECT
			@Clients = d.c.value('@ln', 'NVARCHAR(100)'), -- client

			@Clients_old = od.c.value('@ln', 'NVARCHAR(100)') -- client
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)

		;WITH CTE_Feature AS (
			SELECT
				d.c.value('@fn', 'NVARCHAR(100)') AS Feature, -- Feature
				d.c.value('@fid', 'INT') AS FeatureOrder, -- Feature
				d.c.value('@lld', 'DATE') AS LaunchDate, -- launch date
				d.c.value('@ltd', 'DATE') AS TerminatedDate, -- termination date

				od.c.value('@fn', 'NVARCHAR(100)') AS Feature_old, -- Feature
				od.c.value('@fid', 'INT') AS FeatureOrder_old, -- Feature
				od.c.value('@lld', 'DATE') AS LaunchDate_old, -- launch date
				od.c.value('@ltd', 'DATE') AS TerminatedDate_old -- termination date
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/lf/row') AS Data, CONVERT(XML, OldData).query('/r/lf/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@Client_Features = (SELECT STUFF((SELECT '<br/>' + Feature + CASE WHEN LaunchDate IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate, 101) END + CASE WHEN TerminatedDate IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), TerminatedDate, 101) END FROM (SELECT DISTINCT Feature, FeatureOrder, LaunchDate, TerminatedDate FROM CTE_Feature) CTE_Feature ORDER BY FeatureOrder FOR XML PATH('')), 1, 11, '')),
				@Client_Features_old = (SELECT STUFF((SELECT '<br/>' + Feature_old + CASE WHEN LaunchDate_old IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), LaunchDate_old, 101) END + CASE WHEN TerminatedDate_old IS NULL THEN '' ELSE ' - ' + CONVERT(VARCHAR(10), TerminatedDate_old, 101) END FROM (SELECT DISTINCT Feature_old, FeatureOrder_old, LaunchDate_old, TerminatedDate_old FROM CTE_Feature) CTE_Feature ORDER BY FeatureOrder_old FOR XML PATH('')), 1, 11, ''))

		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Feature - Launch - Termination', @Client_Features, @Client_Features_old)

	END
	ELSE IF @LogActionId IN (400,401,402) -- Insert/Update/Delete Training
	BEGIN
		DECLARE
			@TrainingLicenseeName VARCHAR(50),
			@TrainingStatusName VARCHAR(200),
			@TrainingStatusValue VARCHAR(50),
			@TrainingStatusValue_DateTime DATETIME,
			@TrainingStatusValue_Date VARCHAR(50),
			@TrainingStatusValue_Time VARCHAR(50),
			@Language NVARCHAR(30),
			@Date NVARCHAR(10),
			@StartTime NVARCHAR(20),
			@TimeZone NVARCHAR(10),
			@Attendee NVARCHAR(MAX),

			@TrainingLicenseeName_old VARCHAR(50),
			@TrainingStatusName_old VARCHAR(200),
			@TrainingStatusValue_old VARCHAR(50),
			@TrainingStatusValue_DateTime_old DATETIME,
			@TrainingStatusValue_Date_old VARCHAR(50),
			@TrainingStatusValue_Time_old VARCHAR(50),
			@Language_old NVARCHAR(30),
			@Date_old NVARCHAR(10),
			@StartTime_old NVARCHAR(20),
			@TimeZone_old NVARCHAR(10),
			@Attendee_old NVARCHAR(MAX)

		SELECT
			@TrainingLicenseeName = d.c.value('@ln', 'VARCHAR(50)'), -- licensee
			@TrainingStatusName = d.c.value('@tsn', 'VARCHAR(200)'), -- status
			@TrainingStatusValue = d.c.value('@tsv', 'VARCHAR(50)'), -- status value
			@Language = d.c.value('@lu', 'NVARCHAR(30)'), -- language
			@Date = CONVERT(VARCHAR(10), d.c.value('@td', 'DATE'), 101), -- date
			@StartTime = d.c.value('@td', 'DATETIME'), -- start time
			@TimeZone = d.c.value('@tz', 'NVARCHAR(10)'), -- time zone

			@TrainingLicenseeName_old = od.c.value('@ln', 'VARCHAR(50)'), -- licensee
			@TrainingStatusName_old = od.c.value('@tsn', 'VARCHAR(200)'), -- status
			@TrainingStatusValue_old = od.c.value('@tsv', 'VARCHAR(50)'), -- status value
			@Language_old = od.c.value('@lu', 'NVARCHAR(30)'), -- language
			@Date_old = CONVERT(VARCHAR(10), od.c.value('@td', 'DATE'), 101), -- date
			@StartTime_old = od.c.value('@td', 'DATETIME'), -- start time
			@TimeZone_old = od.c.value('@tz', 'NVARCHAR(10)') -- time zone
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)

		IF ISNULL(@TimeZone, N'') <> N'' AND ISNUMERIC(@TimeZone) = 1
		BEGIN
			SELECT @StartTime = LTRIM(RTRIM(RIGHT(CONVERT(VARCHAR(19), DATEADD(HOUR, CONVERT(INT, @TimeZone), CONVERT(DATETIME, @StartTime)), 100), 7)))
			SELECT @StartTime = LEFT(@StartTime, LEN(@StartTime) - 2) + ' ' + RIGHT(@StartTime, 2)
		END
		
		IF ISNULL(@TimeZone_old, N'') <> N'' AND ISNUMERIC(@TimeZone_old) = 1
		BEGIN
			SELECT @StartTime_old = LTRIM(RTRIM(RIGHT(CONVERT(VARCHAR(19), DATEADD(HOUR, CONVERT(INT, @TimeZone_old), CONVERT(DATETIME, @StartTime_old)), 100), 7)))
			SELECT @StartTime_old = LEFT(@StartTime_old, LEN(@StartTime_old) - 2) + ' ' + RIGHT(@StartTime_old, 2)
		END

		IF ISNULL(@TrainingStatusValue, N'') <> N'' AND ISNUMERIC(@TimeZone) = 1
		BEGIN
			BEGIN TRY
				SELECT @TrainingStatusValue_DateTime = CONVERT(DATETIME, @TrainingStatusValue)
				SELECT @TrainingStatusValue_DateTime = DATEADD(HOUR, CONVERT(INT, @TimeZone), @TrainingStatusValue_DateTime)

				SELECT @TrainingStatusValue_Date = CONVERT(DATE, @TrainingStatusValue_DateTime)

				SELECT @TrainingStatusValue_Time = LTRIM(RTRIM(RIGHT(CONVERT(VARCHAR(19), @TrainingStatusValue_DateTime, 100), 7)))
				SELECT @TrainingStatusValue_Time = LEFT(@TrainingStatusValue_Time, LEN(@TrainingStatusValue_Time) - 2) + ' ' + RIGHT(@TrainingStatusValue_Time, 2)

				
			END TRY
			BEGIN CATCH
				SELECT @TrainingStatusValue_Date = NULL
				SELECT @TrainingStatusValue_Time = NULL
			END CATCH
		END

		IF ISNULL(@TrainingStatusValue_old, N'') <> N'' AND ISNUMERIC(@TimeZone_old) = 1
		BEGIN
			BEGIN TRY
				SELECT @TrainingStatusValue_DateTime_old = CONVERT(DATETIME, @TrainingStatusValue_old)
				SELECT @TrainingStatusValue_DateTime_old = DATEADD(HOUR, CONVERT(INT, @TimeZone_old), @TrainingStatusValue_DateTime_old)

				SELECT @TrainingStatusValue_Date_old = CONVERT(DATE, @TrainingStatusValue_DateTime_old)

				SELECT @TrainingStatusValue_Time_old = LTRIM(RTRIM(RIGHT(CONVERT(VARCHAR(19), @TrainingStatusValue_DateTime_old, 100), 7)))
				SELECT @TrainingStatusValue_Time_old = LEFT(@TrainingStatusValue_Time_old, LEN(@TrainingStatusValue_Time_old) - 2) + ' ' + RIGHT(@TrainingStatusValue_Time_old, 2)

				
			END TRY
			BEGIN CATCH
				SELECT @TrainingStatusValue_Date_old = NULL
				SELECT @TrainingStatusValue_Time_old = NULL
			END CATCH
		END

		IF ISNUMERIC(@TimeZone) = 1
		BEGIN
			IF CONVERT(INT, @TimeZone) < 0
				SELECT @TimeZone = 'GMT' + @TimeZone
			ELSE
				SELECT @TimeZone = 'GMT+' + @TimeZone
		END

		IF ISNUMERIC(@TimeZone_old) = 1
		BEGIN
			IF CONVERT(INT, @TimeZone_old) < 0
				SELECT @TimeZone_old = 'GMT' + @TimeZone_old
			ELSE
				SELECT @TimeZone_old = 'GMT+' + @TimeZone_old
		END

		;WITH CTE_Attendee AS (
			SELECT
				d.c.value('@an', 'NVARCHAR(100)') AS Attendee, -- Attendee
				d.c.value('@ap', 'NVARCHAR(100)') AS Position, -- Position
				d.c.value('@as', 'NVARCHAR(100)') AS Skype, -- Skype

				od.c.value('@an', 'NVARCHAR(100)') AS Attendee_old, -- Attendee
				od.c.value('@ap', 'NVARCHAR(100)') AS Position_old, -- Position
				od.c.value('@as', 'NVARCHAR(100)') AS Skype_old -- Skype
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/a/row') AS Data, CONVERT(XML, OldData).query('/r/a/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		SELECT	@Attendee = (SELECT STUFF((SELECT DISTINCT '<br/>' + Attendee + ' - ' + Position + ' - ' + Skype FROM CTE_Attendee FOR XML PATH('')), 1, 11, '')),
				@Attendee_old = (SELECT STUFF((SELECT DISTINCT '<br/>' + Attendee_old + ' - ' + Position_old + ' - ' + Skype_old FROM CTE_Attendee FOR XML PATH('')), 1, 11, ''))

		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Site name', @TrainingLicenseeName, @TrainingLicenseeName_old),
			(1, N'Language', @Language, @Language_old),
			(2, N'Date', @Date, @Date_old),
			(3, N'Start time', @StartTime, @StartTime_old),
			(4, N'Time zone', @TimeZone, @TimeZone_old),
			(5, N'Attendee - Position - Skype', @Attendee, @Attendee_old),
			(6, N'Status', @TrainingStatusName, @TrainingStatusName_old),
			(7, N'Available Date', @TrainingStatusValue_Date, @TrainingStatusValue_Date_old),
			(8, N'Available Time', @TrainingStatusValue_Time, @TrainingStatusValue_Time_old)
	END
	ELSE IF @LogActionId IN (2000) -- Update User Profile
	BEGIN
		DECLARE
			@User_DisplayName NVARCHAR(100),
			@User_CompanyName NVARCHAR(100),
			@User_PositionName NVARCHAR(100),
			@User_JoinedDate NVARCHAR(100),
			@User_CountryName NVARCHAR(100),
			@User_Email NVARCHAR(100),
			@User_PhoneNumber NVARCHAR(100),
			@User_Skype NVARCHAR(100),
			@User_Line NVARCHAR(100),
			@User_Remark NVARCHAR(100),

			@User_DisplayName_old NVARCHAR(100),
			@User_CompanyName_old NVARCHAR(100),
			@User_PositionName_old NVARCHAR(100),
			@User_JoinedDate_old NVARCHAR(100),
			@User_CountryName_old NVARCHAR(100),
			@User_Email_old NVARCHAR(100),
			@User_PhoneNumber_old NVARCHAR(100),
			@User_Skype_old NVARCHAR(100),
			@User_Line_old NVARCHAR(100),
			@User_Remark_old NVARCHAR(100)

		SELECT
			@User_DisplayName = d.c.value('@udn', 'NVARCHAR(300)'), -- display name
			@User_CompanyName = d.c.value('@ucomn', 'NVARCHAR(300)'), -- company name
			@User_PositionName = d.c.value('@upn', 'NVARCHAR(300)'), -- position
			@User_JoinedDate = d.c.value('@ujd', 'DATE'), -- join date
			@User_CountryName = d.c.value('@ucoun', 'NVARCHAR(300)'), -- country
			@User_Email = d.c.value('@ue', 'NVARCHAR(300)'), -- email
			@User_PhoneNumber = d.c.value('@up', 'NVARCHAR(300)'), -- contact number
			@User_Skype = d.c.value('@us', 'NVARCHAR(300)'), -- skype
			@User_Line = d.c.value('@ul', 'NVARCHAR(300)'), -- line
			@User_Remark = d.c.value('@ur', 'NVARCHAR(300)'), -- remark
			
			@User_DisplayName_old = od.c.value('@udn', 'NVARCHAR(300)'), -- display name
			@User_CompanyName_old = od.c.value('@ucomn', 'NVARCHAR(300)'), -- company name
			@User_PositionName_old = od.c.value('@upn', 'NVARCHAR(300)'), -- position
			@User_JoinedDate_old = od.c.value('@ujd', 'DATE'), -- join date
			@User_CountryName_old = od.c.value('@ucoun', 'NVARCHAR(300)'), -- country
			@User_Email_old = od.c.value('@ue', 'NVARCHAR(300)'), -- email
			@User_PhoneNumber_old = od.c.value('@up', 'NVARCHAR(300)'), -- contact number
			@User_Skype_old = od.c.value('@us', 'NVARCHAR(300)'), -- skype
			@User_Line_old = od.c.value('@ul', 'NVARCHAR(300)'), -- line
			@User_Remark_old = od.c.value('@ur', 'NVARCHAR(300)') -- remark
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)

		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Display name', @User_DisplayName, @User_DisplayName_old),
			(2, N'Company', @User_CompanyName, @User_CompanyName_old),
			(3, N'Position', @User_PositionName, @User_PositionName_old),
			(4, N'Joined date', @User_JoinedDate, @User_JoinedDate_old),
			(5, N'Country base', @User_CountryName, @User_CountryName_old),
			(6, N'Email address', @User_Email, @User_Email_old),
			(7, N'Contact Number', @User_PhoneNumber, @User_PhoneNumber_old),
			(8, N'Skype username', @User_Skype, @User_Skype_old),
			(9, N'Line username', @User_Line, @User_Line_old),
			(10, N'Remark', @User_Remark, @User_Remark_old)
	END
	ELSE IF @LogActionId IN (2001) -- Update Manage Email
	BEGIN
		;WITH CTE_Email AS (
			SELECT
				d.c.value('@lti', 'INT') AS TOLId, -- type of licensee id
				d.c.value('@ltn', 'NVARCHAR(30)') AS TOL, -- type of licensee
				d.c.value('@em', 'NVARCHAR(50)') AS Email, -- email

				od.c.value('@lti', 'INT') AS TOLId_old, -- type of licensee id
				od.c.value('@ltn', 'NVARCHAR(30)') AS TOL_old, -- type of licensee
				od.c.value('@em', 'NVARCHAR(50)') AS Email_old -- email
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<row />') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/ltm/row') AS Data, CONVERT(XML, OldData).query('/r/ltm/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		), CTE_Email_Result AS (
			SELECT DISTINCT c1.TOLId, c1.TOL, c1.Email, c2.Email_old
			FROM CTE_Email c1
				INNER JOIN CTE_Email c2 ON c1.TOLId = c2.TOLId_old 
		)
		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		SELECT ROW_NUMBER() OVER(ORDER BY TOLId), TOL, Email, Email_old
		FROM CTE_Email_Result

	END
	ELSE IF @LogActionId IN (3000,3001,3002) -- Insert/Update/Delete Type Of Licensee
	BEGIN
		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		SELECT
			1,
			N'Type of licensee',

			d.c.value('@ltn', 'NVARCHAR(300)'), -- type of licensee name

			od.c.value('@ltn', 'NVARCHAR(300)') -- type of licensee name
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)
	END
	ELSE IF @LogActionId IN (3003,3004,3005) -- Insert/Update/Delete Product
	BEGIN
		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		SELECT
			1,
			N'Product',

			d.c.value('@pn', 'NVARCHAR(300)'), -- product name

			od.c.value('@pn', 'NVARCHAR(300)') -- product name
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)
	END
	ELSE IF @LogActionId IN (3009,3010,3011) -- Insert/Update/Delete Feature
	BEGIN
		INSERT INTO @Result (Field, NewValue, OldValue)
		SELECT
			N'Feature',

			d.c.value('@fn', 'NVARCHAR(300)'), -- feature

			od.c.value('@fn', 'NVARCHAR(300)') -- feature
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)
	END
	ELSE IF @LogActionId IN (3006,3007,3008) -- Insert/Update/Delete Category
	BEGIN
		DECLARE
			@Category_EN NVARCHAR(100),
			@Category_CN NVARCHAR(200),

			@Category_EN_old NVARCHAR(100),
			@Category_CN_old NVARCHAR(200)
		
		SELECT
			@Category_EN = d.c.value('@cn', 'NVARCHAR(100)'), -- category english
			@Category_CN = d.c.value('@cncn', 'NVARCHAR(200)'), -- category chinese

			@Category_EN_old = od.c.value('@cn', 'NVARCHAR(100)'), -- category english
			@Category_CN_old = od.c.value('@cncn', 'NVARCHAR(200)') -- category chinese
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)

		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Category (English)', @Category_EN, @Category_EN_old),
			(2, N'Category (Simplified Chinese)', @Category_CN, @Category_CN_old)
	END
	ELSE IF @LogActionId IN (3013) -- Update Assign Type Of Licensee
	BEGIN
		;WITH CTE_TOL AS (
			SELECT
				d.c.value('@ltn', 'NVARCHAR(30)') AS TOL, -- Type Of Licensee
				od.c.value('@ltn', 'NVARCHAR(30)') AS TOL_old -- Type Of Licensee
			FROM (
				SELECT
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r><lt><row /></lt></r>') ELSE Data END AS Data,
					CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r><lt><row /></lt></r>') ELSE OldData END AS OldData
				FROM (
					SELECT CONVERT(XML, Data).query('/r/lt/row') AS Data, CONVERT(XML, OldData).query('/r/lt/row') AS OldData
					FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
					WHERE Id = @ActionID
				) B
			) A
				OUTER APPLY A.Data.nodes('row') d(c)
				OUTER APPLY A.OldData.nodes('row') od(c)
		)
		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		SELECT	1, N'Type of licensee',
				(SELECT STUFF((SELECT DISTINCT '<br/>' + TOL FROM CTE_TOL FOR XML PATH('')), 1, 11, '')),
				(SELECT STUFF((SELECT DISTINCT '<br/>' + TOL_old FROM CTE_TOL FOR XML PATH('')), 1, 11, ''))
	END
	ELSE IF @LogActionId IN (3012) -- Update User Position
	BEGIN
		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		SELECT
			1,
			N'Position',

			d.c.value('@upn', 'NVARCHAR(50)'), -- position

			od.c.value('@upn', 'NVARCHAR(50)') -- position
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)
	END
	ELSE IF @LogActionId IN (3014) -- Update Reminder
	BEGIN
		DECLARE 
				@MessageId INT,

				@Reminder_Date NVARCHAR(18),
				@Reminder_Subject NVARCHAR(600),
				@Reminder_Content NVARCHAR(MAX),
				@Reminder_TypeId INT,
				@Reminder_Type NVARCHAR(100),
				@Reminder_Option NVARCHAR(MAX),

				@Reminder_TypeId_Old INT,
				@Reminder_Type_Old NVARCHAR(100),
				@Reminder_Option_Old NVARCHAR(MAX)

		SELECT
			@MessageId = d.c.value('@mi', 'INT'), -- Message id
			@Reminder_TypeId = d.c.value('@rti', 'TINYINT'), -- reminder type id
			@Reminder_Option = d.c.value('@rtv', 'NVARCHAR(MAX)'), -- reminder type value

			@Reminder_TypeId_Old = od.c.value('@rti', 'TINYINT'), -- reminder type id
			@Reminder_Option_Old = od.c.value('@rtv', 'NVARCHAR(MAX)') -- reminder type value
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)
		
		SELECT
			@Reminder_Date = CONVERT(NVARCHAR(10), CreateTime, 101) + ' ' + RIGHT(CONVERT(NVARCHAR(19), CreateTime, 100), 7),
			@Reminder_Subject = SubjectEn,
			@Reminder_Content = ContentEn
		FROM dbo.Message WITH(NOLOCK)
		WHERE MessageId = @MessageId

		SELECT @Reminder_Type = ReminderTypeName
		FROM dbo.ReminderType WITH(NOLOCK) WHERE ReminderTypeId = @Reminder_TypeId

		SELECT @Reminder_Type_Old = ReminderTypeName
		FROM dbo.ReminderType WITH(NOLOCK) WHERE ReminderTypeId = @Reminder_TypeId_Old
		
		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Date', @Reminder_Date, @Reminder_Date),
			(2, N'Subject', @Reminder_Subject, @Reminder_Subject),
			(3, N'Content', @Reminder_Content, @Reminder_Content),
			(4, N'Reminder Type', @Reminder_Type, @Reminder_Type_Old),
			(5, N'Reminder Options', @Reminder_Option, @Reminder_Option_Old)
	END
	ELSE IF @LogActionId IN (4006) -- Update Amendment Notification
	BEGIN
		DECLARE
			@Status NVARCHAR(100),
			@SubjectEn NVARCHAR(300),
			@SubjectCh NVARCHAR(300),
			@SubjectCs NVARCHAR(300),
			@ContentEn NVARCHAR(MAX),
			@ContentCh NVARCHAR(MAX),
			@ContentCs NVARCHAR(MAX),
			
			@Status_old NVARCHAR(100),
			@SubjectEn_old NVARCHAR(300),
			@SubjectCh_old NVARCHAR(300),
			@SubjectCs_old NVARCHAR(300),
			@ContentEn_old NVARCHAR(MAX),
			@ContentCh_old NVARCHAR(MAX),
			@ContentCs_old NVARCHAR(MAX)

		SELECT
			@Status = d.c.value('@sta', 'NVARCHAR(100)'),
			@SubjectEn = d.c.value('@sen', 'NVARCHAR(300)'),
			@SubjectCh = d.c.value('@sch', 'NVARCHAR(300)'),
			@SubjectCs = d.c.value('@scs', 'NVARCHAR(300)'),
			@ContentEn = d.c.value('@cen', 'NVARCHAR(MAX)'),
			@ContentCh = d.c.value('@cch', 'NVARCHAR(MAX)'),
			@ContentCs = d.c.value('@ccs', 'NVARCHAR(MAX)'),
			
			@Status_old = od.c.value('@sta', 'NVARCHAR(100)'),
			@SubjectEn_old = od.c.value('@sen', 'NVARCHAR(300)'),
			@SubjectCh_old = od.c.value('@sch', 'NVARCHAR(300)'),
			@SubjectCs_old = od.c.value('@scs', 'NVARCHAR(300)'),
			@ContentEn_old = od.c.value('@cen', 'NVARCHAR(MAX)'),
			@ContentCh_old = od.c.value('@cch', 'NVARCHAR(MAX)'),
			@ContentCs_old = od.c.value('@ccs', 'NVARCHAR(MAX)')
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)		

		SELECT @Status = CASE WHEN @Status = '1' THEN 'Active'
							  WHEN @Status = '2' THEN 'Inactive'
							  ELSE 'New' END,
			   @Status_old = CASE WHEN @Status_old = '1' THEN 'Active'
							  WHEN @Status_old = '2' THEN 'Inactive'
							  ELSE 'New' END;	
			  
		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Status', @Status, @Status_old),
			(2, N'Subject (English)', @SubjectEn, @SubjectEn_old),
			(3, N'Subject (Trad. Chinese)', @SubjectCh, @SubjectCh_old),
			(4, N'Subject (Smpl. Chinese)', @SubjectCs, @SubjectCs_old),
			(5, N'Content (English)', @ContentEn, @ContentEn_old),
			(6, N'Content (Trad. Chinese)', @ContentCh, @ContentCh_old),
			(7, N'Content (Smpl. Chinese)', @ContentCs, @ContentCs_old)			
	END
	ELSE IF @LogActionId IN (4009) -- Update Reminder
	BEGIN
		DECLARE
			@ReminderMessageId 		NVARCHAR(300),
			@Subject 		NVARCHAR(300),
			
			@ReminderTypeId INT,
			@ReminderType 	NVARCHAR(50),
			@ReminderOption NVARCHAR(MAX),
			
			@ReminderTypeId_old INT,
			@ReminderType_old 	NVARCHAR(50),
			@ReminderOption_old NVARCHAR(MAX)

		SELECT
			@ReminderMessageId = d.c.value('@mi', 'NVARCHAR(300)'),
			
			@ReminderTypeId = d.c.value('@rti', 'NVARCHAR(50)'),
			@ReminderOption = d.c.value('@rtv', 'NVARCHAR(MAX)'),
			
			@ReminderTypeId_old = od.c.value('@rti', 'NVARCHAR(50)'),
			@ReminderOption_old = od.c.value('@rtv', 'NVARCHAR(MAX)')
		FROM (
			SELECT
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(Data, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE Data END AS Data,
				CASE WHEN CONVERT(NVARCHAR(MAX), ISNULL(OldData, N'')) = N'' THEN CONVERT(XML, N'<r />') ELSE OldData END AS OldData
			FROM (
				SELECT CONVERT(XML, Data).query('/r') AS Data, CONVERT(XML, OldData).query('/r') AS OldData
				FROM dbo.UserLog_RunSP_Detail ud WITH(NOLOCK)
				WHERE Id = @ActionID
			) B
		) A
			OUTER APPLY A.Data.nodes('r') d(c)
			OUTER APPLY A.OldData.nodes('r') od(c)		

		SELECT @Subject = SubjectEn
		FROM dbo.Message WITH(NOLOCK)
		WHERE MessageId = @ReminderMessageId

		SELECT @ReminderType = ReminderTypeName
		FROM dbo.ReminderType WITH(NOLOCK) WHERE ReminderTypeId = @ReminderTypeId

		SELECT @ReminderType_old = ReminderTypeName
		FROM dbo.ReminderType WITH(NOLOCK) WHERE ReminderTypeId = @ReminderTypeId_old
			  
		INSERT INTO @Result (ID, Field, NewValue, OldValue)
		VALUES
			(1, N'Subject', @Subject, @Subject),
			(2, N'Reminder Type', @ReminderType, @ReminderType_old),
			(3, N'Reminder Options', @ReminderOption, @ReminderOption_old)		
	END
	
	-- return result
	IF @LogActionId NOT IN (101, 401, 3014) -- Update Contact/Training/Reminder
	BEGIN
		DELETE @Result
		WHERE ISNULL(OldValue, N'') = ISNULL(NewValue, N'')
	END

	;WITH CTE_Result AS (
		SELECT
			ROW_NUMBER() OVER(ORDER BY ID) AS rownum,
			*
		FROM @Result
	)
	SELECT
		rownum, Field, OldValue, NewValue
	FROM CTE_Result
	ORDER BY rownum 
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LogListSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OIC_LogListSel_xtest]
	@UserId			INT,
	@FromDate		DATETIME,
	@ToDate			DATETIME,
	@ActionID		VARCHAR(MAX) = 'All', -- All
	@Target			VARCHAR(50) = '', -- All
	@DoneBy			VARCHAR(50) = '', -- All
		
	@PageSize		INT = 10,
	@PageIndex		INT	= 1,
	@TotalRecords	INT = 0 OUTPUT
AS
/*
	Creator: Percy
	Date: 2016-09-26
	DB: DBOIC.bodb_OIC
	Task: Select Log List [RedmineID: #64713]

	Revisions:
		- 20170328@Percy: Add new function: Client List [RemineID: #70323]
		- 20171019@Scofield: Update log for update Amendment Notification [#84004]

	Param's Explanation:
		- @ActionID: '1,2' -- List of LogActionID
*/
BEGIN
	DECLARE @FDate DATETIME, @TDate DATETIME -- prevent bad parameter sniffing
	SELECT  @FDate = @FromDate, @TDate = @ToDate

	SELECT  @ActionID = ISNULL(@ActionID, ''), @Target = ISNULL(@Target, ''), @DoneBy = ISNULL(@DoneBy, '')
	SELECT  @Target = LTRIM(RTRIM(@Target)), @DoneBy = LTRIM(RTRIM(@DoneBy))
	SELECT  @Target = '%' + @Target + '%', @DoneBy = '%' + @DoneBy + '%'

	CREATE TABLE #LogList (LogID INT, LogDate DATETIME, ActionID INT, OldAction NVARCHAR(MAX), NewAction NVARCHAR(MAX), DoneBy NVARCHAR(100))
	CREATE TABLE #Result (LogID INT, LogDate DATETIME, [Action] VARCHAR(50), [Target] VARCHAR(MAX), DoneBy NVARCHAR(100), IsDetail BIT DEFAULT (1))
	
	DECLARE @ModifyUser TABLE (ID INT PRIMARY KEY, Name NVARCHAR(100)) -- @DoneBy
	INSERT INTO @ModifyUser (ID, Name)
	SELECT UserId AS ID, DisplayName AS Name
	FROM dbo.UserInfo WITH(NOLOCK)
	WHERE DisplayName LIKE @DoneBy

	-- Check user test
	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE UserId = @UserId AND DisplayName LIKE 'starix%')
	BEGIN
		DELETE @ModifyUser WHERE Name LIKE 'starix%'
	END

	DECLARE @Action TABLE (ActionID INT)

	IF EXISTS (SELECT TOP 1 1 FROM @ModifyUser)
	BEGIN
		IF ISNULL(@ActionID, '') <> 'All'
		BEGIN
			INSERT INTO @Action (ActionID)
			SELECT DISTINCT CONVERT(INT, val) FROM dbo.strSplit(@ActionID, ',')
		END
		
		INSERT INTO #LogList (LogID, LogDate, ActionID, OldAction, NewAction, DoneBy)
		SELECT DISTINCT ul.Id, ul.LogDate, ul.LogActionId, uld.OldData, uld.Data, m.Name
		FROM dbo.UserLog_RunSP ul WITH(NOLOCK)
			INNER JOIN dbo.UserLog_RunSP_Detail uld WITH(NOLOCK) ON ul.Id = uld.Id
			INNER JOIN @ModifyUser m ON ul.UserId = m.ID
		WHERE
			(@ActionID = 'All' OR ul.LogActionId IN (SELECT ActionID FROM @Action))
			AND ul.LogDate BETWEEN @FDate AND @TDate
			AND EXISTS (
				SELECT TOP 1 1
				FROM dbo.LogActionType lt WITH(NOLOCK)
					INNER JOIN dbo.LogAction l WITH(NOLOCK) ON lt.LogActionTypeId = l.LogActionTypeId
				WHERE l.[Enable] = 1 AND ul.LogActionId  = l.LogActionId
			) 

		-- Target: Client
		IF EXISTS (SELECT TOP 1 1 FROM dbo.LogAction WITH(NOLOCK) WHERE LogActionTypeId = 1 AND (@ActionID = 'All' OR LogActionId IN (SELECT ActionID FROM @Action)))
		BEGIN
			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], l.LicenseeName, A.DoneBy
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], CONVERT(XML, ISNULL(ISNULL(ll.NewAction, ll.OldAction), N'<r></r>')) AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionTypeId = 1
			) A
				CROSS APPLY A.[Target].nodes('r') d(c)
				INNER JOIN dbo.Licensee l WITH(NOLOCK) ON l.LicenseeId = d.c.value('@lid','INT')
			WHERE l.LicenseeName LIKE @Target

			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], l.LicenseeName, A.DoneBy
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], CONVERT(XML, ISNULL(ISNULL(ll.NewAction, ll.OldAction), N'<r><row /></r>')) AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionTypeId = 1
			) A
				CROSS APPLY A.[Target].nodes('r/row') d(c)
				INNER JOIN dbo.Licensee l WITH(NOLOCK) ON l.LicenseeId = d.c.value('@lid','INT')
			WHERE l.LicenseeName LIKE @Target
		END

		-- Target: Product Name
		IF (@ActionID = 'All' OR EXISTS (SELECT TOP 1 1 FROM @Action WHERE ActionID IN (3003, 3004, 3005, 200)))
		BEGIN
			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], d.c.value('@pn','VARCHAR(100)'), A.DoneBy
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], CONVERT(XML, ISNULL(ISNULL(ll.NewAction, ll.OldAction), N'<r></r>')) AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionId IN (3003, 3004, 3005)
			) A
				CROSS APPLY A.[Target].nodes('r') d(c)
			WHERE d.c.value('@pn','VARCHAR(100)') LIKE @Target

			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], d.c.value('@pn','VARCHAR(100)'), A.DoneBy
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], CONVERT(XML, ISNULL(ISNULL(ll.NewAction, ll.OldAction), N'<r><lp><row /></lp></r>')) AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionId = 200
			) A
				CROSS APPLY A.[Target].nodes('r/lp/row') d(c)
			WHERE d.c.value('@pn','VARCHAR(100)') LIKE @Target
		END
		
		-- Target: Type Of Licensee
		IF (@ActionID = 'All' OR EXISTS (SELECT TOP 1 1 FROM @Action WHERE ActionID IN (3000, 3001, 3002)))
		BEGIN
			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], d.c.value('@ltn','VARCHAR(100)'), A.DoneBy
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], CONVERT(XML, ISNULL(ISNULL(ll.NewAction, ll.OldAction), N'<r></r>')) AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionId IN (3000, 3001, 3002)
			) A
				CROSS APPLY A.[Target].nodes('r') d(c)
			WHERE d.c.value('@ltn','VARCHAR(100)') LIKE @Target
		END
		
		-- Target: Feature
		IF (@ActionID = 'All' OR EXISTS (SELECT TOP 1 1 FROM @Action WHERE ActionID IN (3009, 3010, 3011, 500)))
		BEGIN
			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], d.c.value('@fn','VARCHAR(100)'), A.DoneBy
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], CONVERT(XML, ISNULL(ISNULL(ll.NewAction, ll.OldAction), N'<r></r>')) AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionId IN (3009, 3010, 3011)
			) A
				CROSS APPLY A.[Target].nodes('r') d(c)
			WHERE d.c.value('@fn','VARCHAR(100)') LIKE @Target

			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], d.c.value('@fn','VARCHAR(100)'), A.DoneBy
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], CONVERT(XML, ISNULL(ISNULL(ll.NewAction, ll.OldAction), N'<r><lf><row /></lf></r>')) AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionId = 500
			) A
				CROSS APPLY A.[Target].nodes('r/lf/row') d(c)
			WHERE d.c.value('@fn','VARCHAR(100)') LIKE @Target
		END
		
		-- Target: Category
		IF (@ActionID = 'All' OR EXISTS (SELECT TOP 1 1 FROM @Action WHERE ActionID IN (3006, 3007, 3008)))
		BEGIN
			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], d.c.value('@cn','VARCHAR(100)'), A.DoneBy
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], CONVERT(XML, ISNULL(ISNULL(ll.NewAction, ll.OldAction), N'<r></r>')) AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionId IN (3006, 3007, 3008)
			) A
				CROSS APPLY A.[Target].nodes('r') d(c)
			WHERE d.c.value('@cn','VARCHAR(100)') LIKE @Target
		END
		
		-- Target: User
		IF (@ActionID = 'All' OR EXISTS (SELECT TOP 1 1 FROM @Action WHERE ActionID IN (2000, 2001, 2002, 3012, 3013)))
		BEGIN
			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], d.c.value('@udn','VARCHAR(100)'), A.DoneBy
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], CONVERT(XML, ISNULL(ISNULL(ll.NewAction, ll.OldAction), N'<r></r>')) AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionId IN (2000, 3012)
			) A
				CROSS APPLY A.[Target].nodes('r') d(c)
			WHERE d.c.value('@udn','VARCHAR(100)') LIKE @Target

			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], u.DisplayName, A.DoneBy
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], CONVERT(XML, ISNULL(ISNULL(ll.NewAction, ll.OldAction), N'<r></r>')) AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionId IN (2001, 3013, 3014)
			) A
				CROSS APPLY A.[Target].nodes('r') d(c)
				INNER JOIN dbo.UserInfo u WITH(NOLOCK) ON d.c.value('@uid','VARCHAR(100)') = u.UserId
			WHERE u.DisplayName LIKE @Target

			-- get log update user password from NAP Admin --
			INSERT INTO #LogList (LogID, LogDate, ActionID, OldAction, NewAction, DoneBy)
			SELECT n.Id, n.LogDate, 2002, nd.Data, nd.OldData, m.Name
			FROM bodb_NAPLOG.dbo.NAPLog_RUNSP n WITH(NOLOCK)
				INNER JOIN bodb_NAPLOG.dbo.NAPLOG_RUNSP_Detail nd WITH(NOLOCK) ON n.Id = nd.ID
				INNER JOIN @ModifyUser m ON n.UserId = m.ID
			WHERE n.ActionId = 3 AND n.siteID = 24 -- OIC /*89: local, 24: UAT, PRO*/

			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy, IsDetail)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], u.DisplayName, A.DoneBy, 0
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], CONVERT(XML, ISNULL(ISNULL(ll.NewAction, ll.OldAction), N'<r></r>')) AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionId = 2002
			) A
				CROSS APPLY A.[Target].nodes('r') d(c)
				INNER JOIN dbo.UserInfo u WITH(NOLOCK) ON d.c.value('@ui','VARCHAR(100)') = u.UserId
			WHERE u.DisplayName LIKE @Target
		END
		
		-- Target Notification
		IF (@ActionID = 'All' OR EXISTS (SELECT TOP 1 1 FROM @Action WHERE ActionID IN (4006, 4009)))			
		BEGIN
			INSERT INTO #Result (LogID, LogDate, [Action], [Target], DoneBy)
			SELECT DISTINCT A.LogID, A.LogDate, A.[Action], A.[Target], A.DoneBy
			FROM (
				SELECT ll.LogID, ll.LogDate, la.[ActionNameEn] AS [Action], 'Notification' AS [Target], ll.DoneBy
				FROM #LogList ll
					INNER JOIN dbo.LogAction la WITH(NOLOCK) ON ll.ActionID = la.LogActionId
				WHERE la.LogActionId IN (4006, 4009)
			) A			
		END
	END

	SELECT @TotalRecords = COUNT(*) FROM #Result

	-- paging
	DECLARE @rowStart INT, @rowEnd INT
	SELECT  @rowStart = 1 + @PageIndex * @PageSize, @rowEnd = (@PageIndex + 1) * @PageSize
	
	;WITH CTE_Result AS (
		SELECT
			ROW_NUMBER() OVER(ORDER BY LogDate DESC, LogID DESC) AS rownum,
			*
		FROM #Result
	)
	SELECT
		*
	FROM CTE_Result
	WHERE rownum BETWEEN @rowStart AND @rowEnd
	ORDER BY rownum

	DROP TABLE #LogList
	DROP TABLE #Result
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LogRunSpIns]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LogRunSpIns    Script Date: 5/3/2017 10:41:10 PM ******/
/****** Object:  Stored Procedure dbo.OIC_LogRunSpIns    Script Date: 4/24/2017 10:21:28 AM ******/
/*<info serverAlias="DBOIC-bodb_OIC" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[OIC_LogRunSpIns]
	@UserId			INT			
	,@SPName		VARCHAR(50)	
	,@Language		VARCHAR(20)		= 'EN'
	,@IP			VARCHAR(50)		= NULL
	,@Data			NVARCHAR(MAX)	= NULL	
	,@OldData		NVARCHAR(MAX)	= NULL
	,@Duration		INT				= NULL
AS
/*
	Created by: Kathy
	Date: 2014-12-18
	Task: Add new log user run sp [Redmine:#27752]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20161019@Percy: Support test version (xtest, xpre, UAT1, UAT2, UAT3, UAT4) [RedmineID: #64712]
	
	Param's Explanation:
		* @UserId: UserId perform this action  
		* @ActionId: Log action ID
		* @TrackingValue: XML string format
 */
BEGIN
	SET NOCOUNT ON
	
	DECLARE @logactionid INT

	IF @SPName LIKE '%_xtest'
		SELECT @SPName = LEFT(@SPName, LEN(@SPName) - 6)
	ELSE IF @SPName LIKE '%_xpre' OR @SPName LIKE '%_UAT1' OR @SPName LIKE '%_UAT2' OR @SPName LIKE '%_UAT3' OR @SPName LIKE '%_UAT4'
		SELECT @SPName = LEFT(@SPName, LEN(@SPName) - 5)
	
	SELECT @logactionid = LogActionId
	FROM dbo.LogAction WITH(NOLOCK)
	WHERE SPName = @SPName

	INSERT INTO dbo.UserLog_RunSP (UserId, LogActionId, IP, LogDate, Duration)
	VALUES (@UserId, @logactionid, @IP, GETDATE(), @Duration)
	
	IF @@ERROR = 0
		INSERT INTO dbo.UserLog_RunSP_Detail(LogActionId, Data, OldData)
		VALUES (@logactionid, @Data, @OldData)
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_LogRunSpIns_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_LogRunSpIns_xtest    Script Date: 4/24/2017 10:21:28 AM ******/
/*<info serverAlias="DBOIC-bodb_OIC" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[OIC_LogRunSpIns_xtest]
	@UserId			INT			
	,@SPName		VARCHAR(50)	
	,@Language		VARCHAR(20)		= 'EN'
	,@IP			VARCHAR(50)		= NULL
	,@Data			NVARCHAR(MAX)	= NULL	
	,@OldData		NVARCHAR(MAX)	= NULL
	,@Duration		INT				= NULL
AS
/*
	Created by: Kathy
	Date: 2014-12-18
	Task: Add new log user run sp [Redmine:#27752]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20161019@Percy: Support test version (xtest, xpre, UAT1, UAT2, UAT3, UAT4) [RedmineID: #64712]
	
	Param's Explanation:
		* @UserId: UserId perform this action  
		* @ActionId: Log action ID
		* @TrackingValue: XML string format
 */
BEGIN
	SET NOCOUNT ON
	
	DECLARE @logactionid INT

	IF @SPName LIKE '%_xtest'
		SELECT @SPName = LEFT(@SPName, LEN(@SPName) - 6)
	ELSE IF @SPName LIKE '%_xpre' OR @SPName LIKE '%_UAT1' OR @SPName LIKE '%_UAT2' OR @SPName LIKE '%_UAT3' OR @SPName LIKE '%_UAT4'
		SELECT @SPName = LEFT(@SPName, LEN(@SPName) - 5)
	
	SELECT @logactionid = LogActionId
	FROM dbo.LogAction WITH(NOLOCK)
	WHERE SPName = @SPName

	INSERT INTO dbo.UserLog_RunSP (UserId, LogActionId, IP, LogDate, Duration)
	VALUES (@UserId, @logactionid, @IP, GETDATE(), @Duration)
	
	IF @@ERROR = 0
		INSERT INTO dbo.UserLog_RunSP_Detail(LogActionId, Data, OldData)
		VALUES (@logactionid, @Data, @OldData)
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_ManageUserEmailSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_ManageUserEmailSel    Script Date: 11/21/2016 10:54:26 PM ******/
/****** Object:  Stored Procedure dbo.OIC_ManageUserEmailSel    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_ManageUserEmailSel]
	@UserID INT
AS

/*
	Creator: Percy
	Date: 2016-08-04
	DB: DBOIC.bodb_OIC
	Task: Manage User Mail - Select

	Revisions:
		- 20160823@Percy: Sort TOL by Id [RedmineID: #62883]
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		lt.LicenseeTypeId, lt.LicenseeTypeName, ult.Email
	FROM
		dbo.UserLicenseeType ult WITH(NOLOCK)
		INNER JOIN dbo.LicenseeType lt WITH(NOLOCK) ON ult.LicenseeTypeId = lt.LicenseeTypeId
	WHERE ult.UserId = @UserID
	ORDER BY lt.LicenseeTypeId
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_ManageUserEmailSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_ManageUserEmailSel_xtest    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_ManageUserEmailSel_xtest]
	@UserID INT
AS

/*
	Creator: Percy
	Date: 2016-08-04
	DB: DBOIC.bodb_OIC
	Task: Manage User Mail - Select

	Revisions:
		- 20160823@Percy: Sort TOL by Id [RedmineID: #62883]
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		lt.LicenseeTypeId, lt.LicenseeTypeName, ult.Email
	FROM
		dbo.UserLicenseeType ult WITH(NOLOCK)
		INNER JOIN dbo.LicenseeType lt WITH(NOLOCK) ON ult.LicenseeTypeId = lt.LicenseeTypeId
	WHERE ult.UserId = @UserID
	ORDER BY lt.LicenseeTypeId
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_ManageUserEmailUpd]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_ManageUserEmailUpd    Script Date: 11/21/2016 10:54:27 PM ******/
/****** Object:  Stored Procedure dbo.OIC_ManageUserEmailUpd    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_ManageUserEmailUpd]
	@UserID					INT
	,@LicenseeTypeId_Email	XML
	,@Language				VARCHAR(10)	= 'E'
	,@IP					VARCHAR(50)	= NULL
	,@ErrCode				INT	= 0	OUTPUT
	,@ErrMsg				VARCHAR(300) = NULL OUTPUT
AS

/*
	Creator: Percy
	Date: 2016-08-04
	DB: DBOIC.bodb_OIC
	Task: Manage User Mail - Update

	Revisions:

	Param's Explanation:
		* @LicenseeTypeId_Email:
			<root>
				<row lti="1" em="percy.nguyen@starixsoft.com" />
				<row lti="2" em="muller.nguyen@starixsoft.com" />
				<row lti="3" em="anna.nguyen@starixsoft.com" />
			</root>
*/

BEGIN
	SET NOCOUNT ON

	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPOlddata	NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)

		,@log_email		XML

	DECLARE @tblLicenseeTypeEmail TABLE (LicenseeTypeId TINYINT, LicenseeTypeName VARCHAR(30), Email VARCHAR(50))

	SET @startRun = GETDATE()

	SET @log_email = (
		SELECT
			ult.LicenseeTypeId AS '@lti'
			,lt.LicenseeTypeName AS '@ltn'
			,ult.Email AS '@em'
		FROM
			dbo.UserLicenseeType ult WITH(NOLOCK)
			INNER JOIN dbo.LicenseeType lt WITH(NOLOCK) ON ult.LicenseeTypeId = lt.LicenseeTypeId
		WHERE ult.UserId = @UserID
		FOR XML PATH('row'), ROOT('ltm')
	)

	SET @xml = (SELECT @UserID AS '@uid', @log_email FOR XML PATH('r'), TYPE)		
		
	SELECT @logSPOlddata = CONVERT(NVARCHAR(MAX), @xml)

	IF @log_email IS NOT NULL
	BEGIN TRY
		INSERT INTO @tblLicenseeTypeEmail (LicenseeTypeId, Email)
		SELECT
			t.c.value('@lti', 'tinyint')
			,t.c.value('@em', 'varchar(50)')
		FROM @LicenseeTypeId_Email.nodes('root/row') t(c)

		MERGE dbo.UserLicenseeType u
		USING (SELECT * FROM @tblLicenseeTypeEmail) t
			ON u.LicenseeTypeId = t.LicenseeTypeId AND u.UserID = @UserID
		WHEN MATCHED AND u.Email <> t.Email THEN UPDATE SET u.Email = t.Email
		WHEN NOT MATCHED BY TARGET THEN INSERT (UserId, LicenseeTypeId, Email) VALUES (@UserId, t.LicenseeTypeId, t.Email)
		WHEN NOT MATCHED BY SOURCE AND u.UserId = @UserId THEN DELETE;

		IF @@ROWCOUNT = 0
		BEGIN
			SELECT
				@ErrCode = 100
				,@ErrMsg = dbo.f_Get_MsgNamebyMsgID(30026, @Language)
			RETURN
		END
	END TRY
	BEGIN CATCH
		SELECT
			@ErrCode = 101
			,@ErrMsg = dbo.f_Get_MsgNamebyMsgID(30027, @Language)
		RETURN
	END CATCH

	SET @log_email = (
		SELECT
			ult.LicenseeTypeId AS '@lti'
			,lt.LicenseeTypeName AS '@ltn'
			,ult.Email AS '@em'
		FROM
			dbo.UserLicenseeType ult WITH(NOLOCK)
			INNER JOIN dbo.LicenseeType lt WITH(NOLOCK) ON ult.LicenseeTypeId = lt.LicenseeTypeId
		WHERE ult.UserId = @UserID
		FOR XML PATH('row'), ROOT('ltm')
	)

	SET @xml = (SELECT @UserID AS '@uid', @log_email FOR XML PATH('r'), TYPE)		
		
	SELECT
		@logSPData	= CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)
	
		EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOldData
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_ManageUserEmailUpd_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_ManageUserEmailUpd_xtest    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_ManageUserEmailUpd_xtest]
	@UserID					INT
	,@LicenseeTypeId_Email	XML
	,@Language				VARCHAR(10)	= 'E'
	,@IP					VARCHAR(50)	= NULL
	,@ErrCode				INT	= 0	OUTPUT
	,@ErrMsg				VARCHAR(300) = NULL OUTPUT
AS

/*
	Creator: Percy
	Date: 2016-08-04
	DB: DBOIC.bodb_OIC
	Task: Manage User Mail - Update

	Revisions:

	Param's Explanation:
		* @LicenseeTypeId_Email:
			<root>
				<row lti="1" em="percy.nguyen@starixsoft.com" />
				<row lti="2" em="muller.nguyen@starixsoft.com" />
				<row lti="3" em="anna.nguyen@starixsoft.com" />
			</root>
*/

BEGIN
	SET NOCOUNT ON

	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPOlddata	NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)

		,@log_email		XML

	DECLARE @tblLicenseeTypeEmail TABLE (LicenseeTypeId TINYINT, LicenseeTypeName VARCHAR(30), Email VARCHAR(50))

	SET @startRun = GETDATE()

	SET @log_email = (
		SELECT
			ult.LicenseeTypeId AS '@lti'
			,lt.LicenseeTypeName AS '@ltn'
			,ult.Email AS '@em'
		FROM
			dbo.UserLicenseeType ult WITH(NOLOCK)
			INNER JOIN dbo.LicenseeType lt WITH(NOLOCK) ON ult.LicenseeTypeId = lt.LicenseeTypeId
		WHERE ult.UserId = @UserID
		FOR XML PATH('row'), ROOT('ltm')
	)

	SET @xml = (SELECT @UserID AS '@uid', @log_email FOR XML PATH('r'), TYPE)		
		
	SELECT @logSPOlddata = CONVERT(NVARCHAR(MAX), @xml)

	IF @log_email IS NOT NULL
	BEGIN TRY
		INSERT INTO @tblLicenseeTypeEmail (LicenseeTypeId, Email)
		SELECT
			t.c.value('@lti', 'tinyint')
			,t.c.value('@em', 'varchar(50)')
		FROM @LicenseeTypeId_Email.nodes('root/row') t(c)

		MERGE dbo.UserLicenseeType u
		USING (SELECT * FROM @tblLicenseeTypeEmail) t
			ON u.LicenseeTypeId = t.LicenseeTypeId AND u.UserID = @UserID
		WHEN MATCHED AND u.Email <> t.Email THEN UPDATE SET u.Email = t.Email
		WHEN NOT MATCHED BY TARGET THEN INSERT (UserId, LicenseeTypeId, Email) VALUES (@UserId, t.LicenseeTypeId, t.Email)
		WHEN NOT MATCHED BY SOURCE AND u.UserId = @UserId THEN DELETE;

		IF @@ROWCOUNT = 0
		BEGIN
			SELECT
				@ErrCode = 100
				,@ErrMsg = dbo.f_Get_MsgNamebyMsgID(30026, @Language)
			RETURN
		END
	END TRY
	BEGIN CATCH
		SELECT
			@ErrCode = 101
			,@ErrMsg = dbo.f_Get_MsgNamebyMsgID(30027, @Language)
		RETURN
	END CATCH

	SET @log_email = (
		SELECT
			ult.LicenseeTypeId AS '@lti'
			,lt.LicenseeTypeName AS '@ltn'
			,ult.Email AS '@em'
		FROM
			dbo.UserLicenseeType ult WITH(NOLOCK)
			INNER JOIN dbo.LicenseeType lt WITH(NOLOCK) ON ult.LicenseeTypeId = lt.LicenseeTypeId
		WHERE ult.UserId = @UserID
		FOR XML PATH('row'), ROOT('ltm')
	)

	SET @xml = (SELECT @UserID AS '@uid', @log_email FOR XML PATH('r'), TYPE)		
		
	SELECT
		@logSPData	= CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)
	
	EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOldData
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_MessageTypeSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_MessageTypeSel    Script Date: 1/8/2018 10:37:34 PM ******/
CREATE PROCEDURE [dbo].[OIC_MessageTypeSel] 
	@Mode SMALLINT = 0 -- All
AS

/*
	Created by: Kathy
	Date: 20150730
	Task: select message type  [Redmine:#40305]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20161216@Percy: Support sort message type [RedmineID: #68774]
		- 20171017@Scofield: Support LRF [#84004]
	
	Param's Explanation:
		@Mode = 0: All
				1: internal manual message type
				2: manual external 
				3: internal system + manual
				4: manual external + email
				5: for LRF
*/

BEGIN
	SET NOCOUNT ON
	
	IF @Mode = 0
	BEGIN
		SELECT	MessageTypeId
				,MessageTypeName
		FROM	dbo.MessageType WITH(NOLOCK)
		ORDER BY [Order]
	END
	ELSE IF @Mode = 1
	BEGIN
		SELECT	MessageTypeId
				,MessageTypeName
		FROM	dbo.MessageType WITH(NOLOCK)
		WHERE	(MessageTypeId BETWEEN 20 AND 39 
					OR MessageTypeId = 1 -- News - Manual
				) 
				AND MessageTypeId NOT IN (22, 24) -- Important - System/Reminder
		ORDER BY [Order]
	END
	ELSE IF @Mode = 2
	BEGIN
		SELECT	MessageTypeId
				,MessageTypeName
		FROM	dbo.MessageType WITH(NOLOCK)
		WHERE	MessageTypeId BETWEEN 40 AND 59
		ORDER BY [Order]
	END
	ELSE IF @Mode = 3
	BEGIN
		SELECT	MessageTypeId
				,MessageTypeName
		FROM	dbo.MessageType WITH(NOLOCK)
		WHERE	MessageTypeId BETWEEN 1 AND 39
		ORDER BY [Order]
	END
	ELSE IF @Mode = 4
	BEGIN
		SELECT	MessageTypeId
				,MessageTypeName
		FROM	dbo.MessageType WITH(NOLOCK)
		WHERE	MessageTypeId BETWEEN 40 AND 60
		ORDER BY [Order]
	END
	ELSE IF @Mode = 5
	BEGIN
		SELECT	MessageTypeId
				,MessageTypeName
		FROM	dbo.MessageType WITH(NOLOCK)
		WHERE	MessageTypeId IN (40,41,42,43,44)
		ORDER BY [Order]
	END
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_MessageTypeSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OIC_MessageTypeSel_xtest] 
	@Mode SMALLINT = 0 -- All
AS

/*
	Created by: Kathy
	Date: 20150730
	Task: select message type  [Redmine:#40305]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20161216@Percy: Support sort message type [RedmineID: #68774]
		- 20171017@Scofield: Support LRF [#84004]
	
	Param's Explanation:
		@Mode = 0: All
				1: internal manual message type
				2: manual external 
				3: internal system + manual
				4: manual external + email
				5: for LRF
*/

BEGIN
	SET NOCOUNT ON
	
	IF @Mode = 0
	BEGIN
		SELECT	MessageTypeId
				,MessageTypeName
		FROM	dbo.MessageType WITH(NOLOCK)
		ORDER BY [Order]
	END
	ELSE IF @Mode = 1
	BEGIN
		SELECT	MessageTypeId
				,MessageTypeName
		FROM	dbo.MessageType WITH(NOLOCK)
		WHERE	(MessageTypeId BETWEEN 20 AND 39 
					OR MessageTypeId = 1 -- News - Manual
				) 
				AND MessageTypeId NOT IN (22, 24) -- Important - System/Reminder
		ORDER BY [Order]
	END
	ELSE IF @Mode = 2
	BEGIN
		SELECT	MessageTypeId
				,MessageTypeName
		FROM	dbo.MessageType WITH(NOLOCK)
		WHERE	MessageTypeId BETWEEN 40 AND 59
		ORDER BY [Order]
	END
	ELSE IF @Mode = 3
	BEGIN
		SELECT	MessageTypeId
				,MessageTypeName
		FROM	dbo.MessageType WITH(NOLOCK)
		WHERE	MessageTypeId BETWEEN 1 AND 39
		ORDER BY [Order]
	END
	ELSE IF @Mode = 4
	BEGIN
		SELECT	MessageTypeId
				,MessageTypeName
		FROM	dbo.MessageType WITH(NOLOCK)
		WHERE	MessageTypeId BETWEEN 40 AND 60
		ORDER BY [Order]
	END
	ELSE IF @Mode = 5
	BEGIN
		SELECT	MessageTypeId
				,MessageTypeName
		FROM	dbo.MessageType WITH(NOLOCK)
		WHERE	MessageTypeId IN (40,41,42,43,44)
		ORDER BY [Order]
	END
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_Msg_SystemMsgIns]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_Msg_SystemMsgIns    Script Date: 15/05/2015 10:19:14 AM ******/

CREATE PROCEDURE [dbo].[OIC_Msg_SystemMsgIns] 
	@UserId				INT = 0 -- System
	,@LicenseeTypeId	TINYINT
	,@Subject			NVARCHAR(300)
	,@ContentEn			NVARCHAR(4000)
	,@MessageTypeId		TINYINT 
	,@Action			VARCHAR(15) = 'NewLic'
AS
/*
	Created by: Kathy
	Date: 2014-12-23
	Task: Insert message  [Redmine:#27752]
	DB: DBOIC/BODB_OIC 
	
	Revisions:
	
	Param's Explanation:
		* @SendTo: List UserId will be recieved message
		* @MessageTypeId:	1: news
							2: private
							3: 1On1
							4: AM/PM & 1On1
		* @IsSendAll: send message to all users in system
		* @Action:	NewLic: create new client
					UpdLic: update client
 */
BEGIN
	SET NOCOUNT ON
	
	DECLARE @DisplayName	NVARCHAR(50)
			,@MessageId		INT
			
	DECLARE @tblSendToUsers TABLE(userid INT)
		
	SELECT	@DisplayName  = DisplayName
	FROM dbo.UserInfo WITH(NOLOCK)
	WHERE	UserId = @UserId
		
	IF @Action = 'NewLic'
	BEGIN
		INSERT INTO @tblSendToUsers(userid)
		SELECT	ul.UserId -- AM/PM take care of the @LicenseeType
		FROM dbo.UserLicenseeType ul WITH(NOLOCK)
		WHERE	ul.LicenseeTypeId = @LicenseeTypeId
		UNION
		SELECT	ui.UserId -- Other OIC users
		FROM dbo.UserInfo ui WITH(NOLOCK)
			INNER JOIN dbo.Position p WITH(NOLOCK) 
				ON	ui.PositionId = p.PositionId
		WHERE	p.PositionId BETWEEN 1 AND 4 -- HOD 1On1, HOD PM/AM, 1On1	
	END
	
	IF EXISTS(SELECT TOP 1 1 FROM @tblSendToUsers)
	BEGIN
		INSERT INTO dbo.Message (
				[Subject]
				,ContentEn
				,MessageTypeId
				,Creator
				,CreateName
				,CreateTime
				,LastUpdateBy
				,LastUpdateName
				,LastUpdatedTime
				,IsSystem
				)
			SELECT @Subject
				,@ContentEn
				,@MessageTypeId
				,@UserId
				,@DisplayName
				,GETDATE()
				,@UserId
				,@DisplayName
				,GETDATE()
				,1	
		SET @MessageId = SCOPE_IDENTITY()
				
		INSERT INTO dbo.UserMessage(
				MessageId
				,UserId
				,IsRead
		)
		SELECT	@MessageId
				,ui.UserId
				,0
		FROM dbo.UserInfo ui WITH(NOLOCK)
			INNER JOIN @tblSendToUsers t 
				ON	t.userid = ui.UserId
	END
	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_PositionSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_PositionSel    Script Date: 03/08/2015 3:10:29 PM ******/
CREATE PROCEDURE [dbo].[OIC_PositionSel] 
	@Mode	TINYINT = 0
AS
/*
	Created by: Kathy
	Date: 20150617
	Task: get position [Redmine:#27752]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	Param's Explanation:
		@Mode:	0 - All position
				1 - AM, PM, CSD
		
		
 */
BEGIN
	SET NOCOUNT ON

	SELECT	PositionId
			,PositionName
	FROM	dbo.Position WITH(NOLOCK)
	WHERE	@Mode = 0 
			OR (@Mode = 1 AND PositionId IN (4,5,6))
	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_ProductDel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_ProductDel    Script Date: 11/21/2016 10:54:19 PM ******/
/****** Object:  Stored Procedure dbo.OIC_ProductDel    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_ProductDel] 
	@ProductId				TINYINT
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: delete TOL [Redmine:#44255]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160513@Percy: Add field Order into Product table [RedmineID: #56935]
 */
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
	
	DECLARE @ProductName VARCHAR(50), @Order INT

	SET @startRun = GETDATE()		
	
	SELECT	@ProductName = ProductName, @Order = [Order]
	FROM	dbo.Product WITH(NOLOCK)
	WHERE	ProductId = @ProductId
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.LicenseeProduct WITH(NOLOCK) WHERE ProductId = @ProductId)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30009,@Language) -- Unable to delete the client product because one or many assigned client(s) exist(s)
		RETURN
	END
	
	BEGIN TRY
		DELETE
		FROM	dbo.Product WITH(ROWLOCK, UPDLOCK)
		WHERE	ProductId = @ProductId	
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30010,@Language) -- Fail to delete client product. Please try again.
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	@ProductId		AS '@pi'
				,@ProductName	AS '@pn'
				,@Order			AS '@od'
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

		EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= NULL
		,@OldData		= @logSPData
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_ProductDel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_ProductDel_xtest    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_ProductDel_xtest] 
	@ProductId				TINYINT
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: delete TOL [Redmine:#44255]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160513@Percy: Add field Order into Product table [RedmineID: #56935]
 */
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
	
	DECLARE @ProductName VARCHAR(50), @Order INT

	SET @startRun = GETDATE()		
	
	SELECT	@ProductName = ProductName, @Order = [Order]
	FROM	dbo.Product WITH(NOLOCK)
	WHERE	ProductId = @ProductId
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.LicenseeProduct WITH(NOLOCK) WHERE ProductId = @ProductId)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30009,@Language) -- Unable to delete the client product because one or many assigned client(s) exist(s)
		RETURN
	END
	
	BEGIN TRY
		DELETE
		FROM	dbo.Product WITH(ROWLOCK, UPDLOCK)
		WHERE	ProductId = @ProductId	
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30010,@Language) -- Fail to delete client product. Please try again.
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	@ProductId		AS '@pi'
				,@ProductName	AS '@pn'
				,@Order			AS '@od'
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= NULL
		,@OldData		= @logSPData
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_ProductIns]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_ProductIns    Script Date: 11/21/2016 10:54:20 PM ******/
/****** Object:  Stored Procedure dbo.OIC_ProductIns    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_ProductIns] 
	@ProductName			VARCHAR(50)
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: insert new product [Redmine:#44255]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160513@Percy: Add field Order into Product table [RedmineID: #56935]
 */
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)


	DECLARE @ProductId TINYINT, @Order INT

	SET @startRun = GETDATE()		
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.Product WITH(NOLOCK) WHERE ProductName = @ProductName)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30006, @Language) -- The product name is already used. Please try another name.
		RETURN
	END
	
	BEGIN TRY
		SELECT @Order = MAX([Order]) FROM dbo.Product WITH (NOLOCK)
		SELECT @Order = @Order + 10
		INSERT INTO dbo.Product (ProductName, [Order]) VALUES (@ProductName, @Order)
	
		SET @ProductId = SCOPE_IDENTITY()
	
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30007, @Language) -- Fail to create client product. Please try again.
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	@ProductId		AS '@pi'
				,@productname	AS '@pn'
				,@Order			AS '@od'
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

		EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_ProductIns_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_ProductIns_xtest    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_ProductIns_xtest] 
	@ProductName			VARCHAR(50)
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: insert new product [Redmine:#44255]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160513@Percy: Add field Order into Product table [RedmineID: #56935]
 */
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)


	DECLARE @ProductId TINYINT, @Order INT

	SET @startRun = GETDATE()		
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.Product WITH(NOLOCK) WHERE ProductName = @ProductName)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30006, @Language) -- The product name is already used. Please try another name.
		RETURN
	END
	
	BEGIN TRY
		SELECT @Order = MAX([Order]) FROM dbo.Product WITH (NOLOCK)
		SELECT @Order = @Order + 10
		INSERT INTO dbo.Product (ProductName, [Order]) VALUES (@ProductName, @Order)
	
		SET @ProductId = SCOPE_IDENTITY()
	
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30007, @Language) -- Fail to create client product. Please try again.
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	@ProductId		AS '@pi'
				,@productname	AS '@pn'
				,@Order			AS '@od'
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_ProductSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_ProductSel    Script Date: 6/20/2016 11:20:43 PM ******/
/****** Object:  Stored Procedure dbo.OIC_ProductSel    Script Date: 6/7/2016 4:13:25 PM ******/

CREATE PROCEDURE [dbo].[OIC_ProductSel] 
AS
/*
	Created by: Kathy
	Date: 2014-12-25
	Task: Get Product [Redmine:#27752]
	DB: DBOIC/BODB_OIC 
	
	Revisions:
		- 20160506@Percy: Re-arrange order product [Redmine: #56935]
		
 */
BEGIN
	SET NOCOUNT ON
	
	SELECT	ProductId
			,ProductName
	FROM dbo.Product WITH(NOLOCK)
	ORDER BY [Order]
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_ProductSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_ProductSel_xtest    Script Date: 6/7/2016 4:13:25 PM ******/

CREATE PROCEDURE [dbo].[OIC_ProductSel_xtest] 
AS
/*
	Created by: Kathy
	Date: 2014-12-25
	Task: Get Product [Redmine:#27752]
	DB: DBOIC/BODB_OIC 
	
	Revisions:
		- 20160506@Percy: Re-arrange order product [Redmine: #56935]
		
 */
BEGIN
	SET NOCOUNT ON
	
	SELECT	ProductId
			,ProductName
	FROM dbo.Product WITH(NOLOCK)
	ORDER BY [Order]
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_ProductUpd]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_ProductUpd    Script Date: 11/21/2016 10:54:22 PM ******/
/****** Object:  Stored Procedure dbo.OIC_ProductUpd    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_ProductUpd] 
	@ProductId				TINYINT
	,@ProductName			VARCHAR(50)
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: update product [Redmine:#44255]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160513@Percy: Add field Order into Product table [RedmineID: #56935]
 */
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPOlddata	NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)

	SET @startRun = GETDATE()
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.Product WITH(NOLOCK) WHERE ProductName = @ProductName)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30006, @Language) -- The product name is already used. Please try another name.
		RETURN
	END		
	
	SET @xml = (
		SELECT	ProductId		AS '@pi'
				,ProductName	AS '@pn'
				,[Order]		AS '@od'
		FROM	dbo.Product WITH(NOLOCK)
		WHERE	ProductId = @ProductId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPOlddata = CONVERT(NVARCHAR(MAX), @xml)
	
	BEGIN TRY
		UPDATE	dbo.Product WITH(ROWLOCK, UPDLOCK)
			SET	ProductName = @ProductName
		WHERE	ProductId = @ProductId	
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30008, @Language) -- Fail to edit client product. Please try again.
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	ProductId		AS '@pi'
				,ProductName	AS '@pn'
				,[Order]		AS '@od'
		FROM	dbo.Product WITH(NOLOCK)
		WHERE	ProductId = @ProductId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX),@xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

		EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOlddata
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_ProductUpd_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_ProductUpd_xtest    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_ProductUpd_xtest] 
	@ProductId				TINYINT
	,@ProductName			VARCHAR(50)
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 201501001
	Task: update product [Redmine:#44255]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160513@Percy: Add field Order into Product table [RedmineID: #56935]
 */
BEGIN
	SET NOCOUNT ON
	
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPOlddata	NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)

	SET @startRun = GETDATE()
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.Product WITH(NOLOCK) WHERE ProductName = @ProductName)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30006, @Language) -- The product name is already used. Please try another name.
		RETURN
	END		
	
	SET @xml = (
		SELECT	ProductId		AS '@pi'
				,ProductName	AS '@pn'
				,[Order]		AS '@od'
		FROM	dbo.Product WITH(NOLOCK)
		WHERE	ProductId = @ProductId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPOlddata = CONVERT(NVARCHAR(MAX), @xml)
	
	BEGIN TRY
		UPDATE	dbo.Product WITH(ROWLOCK, UPDLOCK)
			SET	ProductName = @ProductName
		WHERE	ProductId = @ProductId	
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30008, @Language) -- Fail to edit client product. Please try again.
		RETURN
	END CATCH
	
	SET @xml = (
		SELECT	ProductId		AS '@pi'
				,ProductName	AS '@pn'
				,[Order]		AS '@od'
		FROM	dbo.Product WITH(NOLOCK)
		WHERE	ProductId = @ProductId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX),@xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOlddata
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_ReminderSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_ReminderSel    Script Date: 3/13/2017 11:46:33 PM ******/
/****** Object:  Stored Procedure dbo.OIC_ReminderSel    Script Date: 3/2/2017 10:06:15 AM ******/

CREATE PROCEDURE [dbo].[OIC_ReminderSel]
	@UserId				INT,
	@SelectedReminder	VARCHAR(1000) = 'All',
	@FromDate			DATETIME,
	@ToDate				DATETIME,
	@SelectedSender		VARCHAR(MAX) = 'All',

	@PageSize			INT = 10,
	@PageIndex			INT = 0,
	@TotalRecords		INT = 0 OUTPUT
AS

/*
	Creator: Percy
	Date: 2016-12-15
	DB: DBOIC.bodb_OIC
	Task: System Configuration - Select Reminder

	Revisions:
		- 20170302@Percy: Expand length of Content [RedmineID: #70322]

	Param's Explanation:
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @RowStart INT, @RowEnd INT
	SELECT	@PageIndex	= @PageIndex 
			,@RowStart	= @PageSize * @PageIndex + 1
			,@RowEnd	= @RowStart + @PageSize - 1

	DECLARE @tblSender TABLE (UserId INT)
	DECLARE @tblReminder TABLE (ReminderTypeId TINYINT)
	DECLARE @tblLicenseeType TABLE (LicenseeTypeId TINYINT)
	DECLARE @PositionId	TINYINT
	CREATE TABLE #tblMessage
	(
		MessageId			INT PRIMARY KEY
		,MessageTypeId		TINYINT
		,CreateTime			DATETIME
		,SenderId			INT
		,SubjectEn			NVARCHAR(300)
		,ContentEn			NVARCHAR(MAX)
		,IsRead				BIT
		,IsDisable			BIT
		,ReminderTypeId		TINYINT
		,ReminderTypeValue	XML
	)

	INSERT INTO @tblLicenseeType (LicenseeTypeId)
	SELECT	LicenseeTypeId
	FROM	dbo.UserLicenseeType WITH(NOLOCK)
	WHERE	UserId = @UserId

	SELECT	@PositionId = PositionId
	FROM	dbo.UserInfo WITH(NOLOCK)
	WHERE	UserId = @UserId

	IF @SelectedSender <> 'All'
	BEGIN
		INSERT INTO @tblSender (UserId)
		SELECT	val 
		FROM	dbo.strSplit(@SelectedSender, ',')
	END	

	IF @SelectedReminder <> 'All'
	BEGIN
		INSERT INTO @tblReminder (ReminderTypeId)
		SELECT	val 
		FROM	dbo.strSplit(@SelectedReminder, ',')
	END	

	INSERT INTO #tblMessage (MessageId, MessageTypeId, CreateTime, SenderId, SubjectEn, ContentEn, IsRead, IsDisable, ReminderTypeId, ReminderTypeValue)
	SELECT  m.MessageId, m.MessageTypeId, m.CreateTime, m.Creator, m.SubjectEn, m.ContentEn, um.IsRead, 0, m.ReminderTypeId, m.ReminderTypeValue
	FROM	dbo.Message m WITH(NOLOCK)
		INNER JOIN dbo.UserMessage um WITH(NOLOCK) ON m.MessageId = um.MessageId
	WHERE	m.MessageTypeId IN (21, 24)
			AND m.CreateTime BETWEEN @FromDate AND @ToDate
			AND (m.Creator IN (SELECT UserId FROM @tblSender) OR @SelectedSender = 'All')
			AND um.UserId = @UserId
			AND (
				@SelectedReminder = 'All'
				OR ISNULL(m.ReminderTypeId, 1) IN (SELECT ReminderTypeId FROM @tblReminder)
			)
	
	SET @TotalRecords = @@ROWCOUNT

	;WITH cteMessageTarget AS (
		SELECT m.MessageId, m.MessageTypeId, m.CreateTime, m.Creator, m.SubjectEn, m.ContentEn, m.ReminderTypeId, m.ReminderTypeValue
		FROM dbo.Message m WITH(NOLOCK)
			INNER JOIN dbo.MessageTarget mt WITH(NOLOCK) ON	m.MessageId = mt.MessageId
		WHERE	m.MessageTypeId IN (21, 24)
				AND m.CreateTime BETWEEN @FromDate AND @ToDate
				AND (m.Creator IN (SELECT UserId FROM @tblSender) OR @SelectedSender = 'All')
				AND (mt.LicenseeTypeId IN (SELECT t.LicenseeTypeId FROM @tblLicenseeType t)
						OR mt.PositionId = @PositionId
					)
				AND m.MessageId NOT IN (SELECT MessageId FROM #tblMessage)
				AND (
					@SelectedReminder = 'All'
					OR ISNULL(m.ReminderTypeId, 1) IN (SELECT ReminderTypeId FROM @tblReminder)
				)
		--GROUP BY m.MessageId, m.MessageTypeId, m.CreateTime, m.Creator, m.SubjectEn, m.ContentEn, m.ReminderTypeId, m.ReminderTypeValue
	)
	INSERT INTO #tblMessage (MessageId, MessageTypeId, CreateTime, SenderId, SubjectEn, ContentEn, IsRead, IsDisable, ReminderTypeId, ReminderTypeValue)
	SELECT	MessageId, MessageTypeId, CreateTime, Creator, SubjectEn, ContentEn, 1, 1, ReminderTypeId, ReminderTypeValue
	FROM cteMessageTarget
	
	SET @TotalRecords = @TotalRecords + @@ROWCOUNT

	-- Result
	CREATE TABLE #Result (RowNumber INT, MessageId INT, MessageTypeId TINYINT, CreateTime DATETIME, SenderId INT,
						SubjectEn NVARCHAR(300), ContentEn NVARCHAR(MAX), IsRead BIT, IsDisable BIT, ReminderTypeId TINYINT, ReminderTypeValue XML)

	INSERT INTO #Result (RowNumber, MessageId, MessageTypeId, CreateTime, SenderId, SubjectEn, ContentEn, IsRead, IsDisable, ReminderTypeId, ReminderTypeValue)
	SELECT RowNumber, MessageId, MessageTypeId, CreateTime, SenderId, SubjectEn, ContentEn, IsRead, IsDisable, ISNULL(ReminderTypeId, 1), ReminderTypeValue
	FROM (
		SELECT	ROW_NUMBER() OVER(ORDER BY MessageTypeId DESC, CreateTime DESC) AS RowNumber
				,MessageId, MessageTypeId, CreateTime, SenderId, SubjectEn, ContentEn, IsRead, IsDisable, ReminderTypeId, ReminderTypeValue
		FROM #tblMessage
	) Result
	WHERE RowNumber BETWEEN @RowStart AND @RowEnd

	-- Return data
	SELECT r.*, rt.ReminderTypeName, u.DisplayName AS Sender
	FROM #Result r
		LEFT JOIN dbo.ReminderType rt WITH(NOLOCK) ON r.ReminderTypeId = rt.ReminderTypeId
		INNER JOIN dbo.UserInfo u WITH(NOLOCK) ON r.SenderId = u.UserId
	ORDER BY r.RowNumber

	DROP TABLE #Result
	DROP TABLE #tblMessage
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_ReminderSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_ReminderSel_xtest    Script Date: 3/2/2017 10:06:15 AM ******/

CREATE PROCEDURE [dbo].[OIC_ReminderSel_xtest]
	@UserId				INT,
	@SelectedReminder	VARCHAR(1000) = 'All',
	@FromDate			DATETIME,
	@ToDate				DATETIME,
	@SelectedSender		VARCHAR(MAX) = 'All',

	@PageSize			INT = 10,
	@PageIndex			INT = 0,
	@TotalRecords		INT = 0 OUTPUT
AS

/*
	Creator: Percy
	Date: 2016-12-15
	DB: DBOIC.bodb_OIC
	Task: System Configuration - Select Reminder

	Revisions:
		- 20170302@Percy: Expand length of Content [RedmineID: #70322]

	Param's Explanation:
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @RowStart INT, @RowEnd INT
	SELECT	@PageIndex	= @PageIndex 
			,@RowStart	= @PageSize * @PageIndex + 1
			,@RowEnd	= @RowStart + @PageSize - 1

	DECLARE @tblSender TABLE (UserId INT)
	DECLARE @tblReminder TABLE (ReminderTypeId TINYINT)
	DECLARE @tblLicenseeType TABLE (LicenseeTypeId TINYINT)
	DECLARE @PositionId	TINYINT
	CREATE TABLE #tblMessage
	(
		MessageId			INT PRIMARY KEY
		,MessageTypeId		TINYINT
		,CreateTime			DATETIME
		,SenderId			INT
		,SubjectEn			NVARCHAR(300)
		,ContentEn			NVARCHAR(MAX)
		,IsRead				BIT
		,IsDisable			BIT
		,ReminderTypeId		TINYINT
		,ReminderTypeValue	XML
	)

	INSERT INTO @tblLicenseeType (LicenseeTypeId)
	SELECT	LicenseeTypeId
	FROM	dbo.UserLicenseeType WITH(NOLOCK)
	WHERE	UserId = @UserId

	SELECT	@PositionId = PositionId
	FROM	dbo.UserInfo WITH(NOLOCK)
	WHERE	UserId = @UserId

	IF @SelectedSender <> 'All'
	BEGIN
		INSERT INTO @tblSender (UserId)
		SELECT	val 
		FROM	dbo.strSplit(@SelectedSender, ',')
	END	

	IF @SelectedReminder <> 'All'
	BEGIN
		INSERT INTO @tblReminder (ReminderTypeId)
		SELECT	val 
		FROM	dbo.strSplit(@SelectedReminder, ',')
	END	

	INSERT INTO #tblMessage (MessageId, MessageTypeId, CreateTime, SenderId, SubjectEn, ContentEn, IsRead, IsDisable, ReminderTypeId, ReminderTypeValue)
	SELECT  m.MessageId, m.MessageTypeId, m.CreateTime, m.Creator, m.SubjectEn, m.ContentEn, um.IsRead, 0, m.ReminderTypeId, m.ReminderTypeValue
	FROM	dbo.Message m WITH(NOLOCK)
		INNER JOIN dbo.UserMessage um WITH(NOLOCK) ON m.MessageId = um.MessageId
	WHERE	m.MessageTypeId IN (21, 24)
			AND m.CreateTime BETWEEN @FromDate AND @ToDate
			AND (m.Creator IN (SELECT UserId FROM @tblSender) OR @SelectedSender = 'All')
			AND um.UserId = @UserId
			AND (
				@SelectedReminder = 'All'
				OR ISNULL(m.ReminderTypeId, 1) IN (SELECT ReminderTypeId FROM @tblReminder)
			)
	
	SET @TotalRecords = @@ROWCOUNT

	;WITH cteMessageTarget AS (
		SELECT m.MessageId, m.MessageTypeId, m.CreateTime, m.Creator, m.SubjectEn, m.ContentEn, m.ReminderTypeId, m.ReminderTypeValue
		FROM dbo.Message m WITH(NOLOCK)
			INNER JOIN dbo.MessageTarget mt WITH(NOLOCK) ON	m.MessageId = mt.MessageId
		WHERE	m.MessageTypeId IN (21, 24)
				AND m.CreateTime BETWEEN @FromDate AND @ToDate
				AND (m.Creator IN (SELECT UserId FROM @tblSender) OR @SelectedSender = 'All')
				AND (mt.LicenseeTypeId IN (SELECT t.LicenseeTypeId FROM @tblLicenseeType t)
						OR mt.PositionId = @PositionId
					)
				AND m.MessageId NOT IN (SELECT MessageId FROM #tblMessage)
				AND (
					@SelectedReminder = 'All'
					OR ISNULL(m.ReminderTypeId, 1) IN (SELECT ReminderTypeId FROM @tblReminder)
				)
		--GROUP BY m.MessageId, m.MessageTypeId, m.CreateTime, m.Creator, m.SubjectEn, m.ContentEn, m.ReminderTypeId, m.ReminderTypeValue
	)
	INSERT INTO #tblMessage (MessageId, MessageTypeId, CreateTime, SenderId, SubjectEn, ContentEn, IsRead, IsDisable, ReminderTypeId, ReminderTypeValue)
	SELECT	MessageId, MessageTypeId, CreateTime, Creator, SubjectEn, ContentEn, 1, 1, ReminderTypeId, ReminderTypeValue
	FROM cteMessageTarget
	
	SET @TotalRecords = @TotalRecords + @@ROWCOUNT

	-- Result
	CREATE TABLE #Result (RowNumber INT, MessageId INT, MessageTypeId TINYINT, CreateTime DATETIME, SenderId INT,
						SubjectEn NVARCHAR(300), ContentEn NVARCHAR(MAX), IsRead BIT, IsDisable BIT, ReminderTypeId TINYINT, ReminderTypeValue XML)

	INSERT INTO #Result (RowNumber, MessageId, MessageTypeId, CreateTime, SenderId, SubjectEn, ContentEn, IsRead, IsDisable, ReminderTypeId, ReminderTypeValue)
	SELECT RowNumber, MessageId, MessageTypeId, CreateTime, SenderId, SubjectEn, ContentEn, IsRead, IsDisable, ISNULL(ReminderTypeId, 1), ReminderTypeValue
	FROM (
		SELECT	ROW_NUMBER() OVER(ORDER BY MessageTypeId DESC, CreateTime DESC) AS RowNumber
				,MessageId, MessageTypeId, CreateTime, SenderId, SubjectEn, ContentEn, IsRead, IsDisable, ReminderTypeId, ReminderTypeValue
		FROM #tblMessage
	) Result
	WHERE RowNumber BETWEEN @RowStart AND @RowEnd

	-- Return data
	SELECT r.*, rt.ReminderTypeName, u.DisplayName AS Sender
	FROM #Result r
		LEFT JOIN dbo.ReminderType rt WITH(NOLOCK) ON r.ReminderTypeId = rt.ReminderTypeId
		INNER JOIN dbo.UserInfo u WITH(NOLOCK) ON r.SenderId = u.UserId
	ORDER BY r.RowNumber

	DROP TABLE #Result
	DROP TABLE #tblMessage
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_ReminderUpd]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_ReminderUpd    Script Date: 2/7/2017 9:25:02 AM ******/

CREATE PROCEDURE [dbo].[OIC_ReminderUpd]
	@UserId				INT,
	@MessageId			INT,
	@ReminderTypeId		TINYINT,
	@ReminderTypeValue	XML = NULL,

	@Language			VARCHAR(10)		= 'E',
	@IP					VARCHAR(50)		= NULL,
	@ErrCode			INT				= 0		OUTPUT,
	@ErrMsg				VARCHAR(2000)	= ''	OUTPUT
AS

/*
	Creator: Percy
	Date: 2016-12-15
	DB: DBOIC.bodb_OIC
	Task: System Configuration - Update Reminder

	Revisions:

	Param's Explanation:
		- @ReminderType: type of reminder
			. 1: None
			. 2: Daily
			. 3: Weekly
			. 4: Monthly
			. 5: Yearly
		- @ReminderValue: value of reminder
			. None, Daily: = NULL
			. Weekly, Monthly, Yearly: '<root>
											<r id="", value="">
										</root>'
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @startTime DATETIME, @duration INT, @logSPData NVARCHAR(MAX), @logSPOldData NVARCHAR(MAX), @xml XML, @procName VARCHAR(200)
	SELECT  @startTime = GETDATE()

	-- check condition Important - Manual/Reminder
	IF NOT EXISTS (SELECT 1 FROM dbo.Message WITH(NOLOCK) WHERE MessageId = @MessageId AND MessageTypeId IN (21, 24))
	BEGIN
		SELECT	@ErrCode = 100,
				@ErrMsg = 'This message is not Important - Manual or Important - Reminder'
		RETURN
	END

	-- check input valid --
	IF @ReminderTypeId = 5 -- Yearly
	BEGIN
		DECLARE @dateInvalid VARCHAR(MAX)
		IF LEFT(REPLACE(REPLACE(CONVERT(VARCHAR(MAX), @ReminderTypeValue), ';', ','), ' ', ','), 1) = ','
			OR RIGHT(REPLACE(REPLACE(CONVERT(VARCHAR(MAX), @ReminderTypeValue), ';', ','), ' ', ','), 1) = ','
		BEGIN
			SELECT	@ErrCode = 101,
					@ErrMsg = 'Invalid date: '
			RETURN
		END

		IF EXISTS (
				SELECT rank, LTRIM(RTRIM(val))
				FROM dbo.strSplit(REPLACE(CONVERT(VARCHAR(MAX), @ReminderTypeValue), ';', ','), ',')
				WHERE CHARINDEX('/', LTRIM(RTRIM(val))) = 0
		)
		BEGIN
			SELECT TOP 1 @dateInvalid = LTRIM(RTRIM(val))
			FROM dbo.strSplit(REPLACE(CONVERT(VARCHAR(MAX), @ReminderTypeValue), ';', ','), ',')
			WHERE CHARINDEX('/', LTRIM(RTRIM(val))) = 0
			
			SELECT	@ErrCode = 101,
					@ErrMsg = 'Invalid date: ' + @dateInvalid
			RETURN
		END

		DECLARE @tblCheck TABLE (ID INT, val NVARCHAR(MAX))

		INSERT INTO @tblCheck (ID, val)
		SELECT rank, LTRIM(RTRIM(val))
		FROM dbo.strSplit(REPLACE(REPLACE(CONVERT(VARCHAR(MAX), @ReminderTypeValue), ';', ','), ' ', ','), ',')

		DELETE @tblCheck WHERE val = ''

		IF NOT EXISTS (SELECT 1 FROM @tblCheck)
		BEGIN
			SELECT @dateInvalid = ''
		END
		ELSE IF EXISTS (SELECT 1 FROM @tblCheck WHERE CHARINDEX('/', val) = 0)
		BEGIN
			SELECT TOP 1 @dateInvalid = val
			FROM @tblCheck WHERE CHARINDEX('/', val) = 0
			ORDER BY ID
		END
		ELSE IF EXISTS (SELECT 1 FROM @tblCheck t CROSS APPLY dbo.strSplit(t.val, '/') s WHERE LEN(t.val) > 5 OR LEN(s.val) > 2)
		BEGIN
			SELECT TOP 1 @dateInvalid = t.val
			FROM @tblCheck t
				CROSS APPLY dbo.strSplit(t.val, '/') s
			WHERE LEN(t.val) > 5 OR LEN(s.val) > 2
			ORDER BY t.ID
		END
		ELSE
		BEGIN
			UPDATE @tblCheck
			SET val = 
				CASE WHEN LEN(LEFT(val, CHARINDEX('/', val) - 1)) = 1 THEN '0' + LEFT(val, CHARINDEX('/', val) - 1) ELSE LEFT(val, CHARINDEX('/', val) - 1) END
				+ '/' +
				CASE WHEN LEN(RIGHT(val, LEN(val) - CHARINDEX('/', val))) = 1 THEN '0' + RIGHT(val, LEN(val) - CHARINDEX('/', val)) ELSE RIGHT(val, LEN(val) - CHARINDEX('/', val)) END

			SELECT TOP 1 @dateInvalid = val
			FROM @tblCheck
			WHERE ISDATE(val + '/1970') = 0
		END

		IF @dateInvalid IS NOT NULL
		BEGIN
			SELECT	@ErrCode = 101,
					@ErrMsg = 'Invalid date: ' + @dateInvalid
			RETURN
		END

		IF (SELECT COUNT(1) FROM @tblCheck) > 30
		BEGIN
			SELECT	@ErrCode = 102,
					@ErrMsg = 'Too many dates inputed (exceed 30 dates)'
			RETURN
		END
	END

	-- get old data before update
	SELECT	@xml = 
	(
		SELECT
			@UserId			AS '@uid',
			MessageId		AS '@mi',
			MessageTypeId	AS '@mti',
			ReminderTypeId	AS '@rti',
			CONVERT(NVARCHAR(MAX), ReminderTypeValue) AS '@rtv'
		FROM dbo.Message WITH(NOLOCK)
		WHERE MessageId = @MessageId
		FOR XML PATH('r'), TYPE
	)

	SELECT  @logSPOldData = CONVERT(NVARCHAR(MAX), @xml)

	BEGIN TRY
		UPDATE dbo.Message WITH(ROWLOCK, UPDLOCK)
		SET
			MessageTypeId		= CASE WHEN @ReminderTypeId = 1 THEN 21 ELSE 24 END,
			ReminderTypeId		= @ReminderTypeId,
			ReminderTypeValue	= CASE WHEN @ReminderTypeId IN (1, 2) THEN NULL ELSE @ReminderTypeValue END
		WHERE MessageId = @MessageId
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 103,
				@ErrMsg = 'Update failed! Please try again!'
		RETURN
	END CATCH

	-- get new data after update
	SELECT	@xml = 
	(
		SELECT
			@UserId			AS '@uid',
			MessageId		AS '@mi',
			MessageTypeId	AS '@mti',
			ReminderTypeId	AS '@rti',
			CONVERT(NVARCHAR(MAX), ReminderTypeValue) AS '@rtv'
		FROM dbo.Message WITH(NOLOCK)
		WHERE MessageId = @MessageId
		FOR XML PATH('r'), TYPE
	)

	SELECT  @logSPData = CONVERT(NVARCHAR(MAX), @xml)

	-- write log
	SELECT	@duration = DATEDIFF(MILLISECOND, @startTime, GETDATE()),
			@procName = OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns
		@UserId		= @UserId,
		@SPName		= @procName,
		@Language	= @Language,
		@IP			= @IP,
		@Data		= @logSPData,
		@OldData	= @logSPOldData,
		@Duration	= @duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_ServicePropertySel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_ServicePropertySel    Script Date: 15/05/2015 10:19:14 AM ******/
CREATE PROCEDURE [dbo].[OIC_ServicePropertySel]
AS

/*
	Created by: Dom
	Date: 2014-12-18
	Task: Get ServiceProperty [Redmine:#27752]
	DB: DBOIC/BODB_OIC 
	
	Revisions:
		
 */

BEGIN
	SET NOCOUNT ON;
	SELECT	s.ServiceId
			,s.ServiceName
			,p.PropertyId
			,p.PropertyName
			,p.DefaultValue
			,p.PropertyType
			,p.[Order]
			,s.ServiceHint AS Hint
			,p.MaxLength
	FROM Service s WITH(NOLOCK)
		INNER JOIN dbo.Property p WITH(NOLOCK) 
			ON	s.ServiceId = p.ServiceId
	ORDER BY s.ServiceId
			,p.[Order]
END

GO
/****** Object:  StoredProcedure [dbo].[OIC_SystemNotificationIns]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_SystemNotificationIns    Script Date: 3/13/2017 11:46:32 PM ******/
/****** Object:  Stored Procedure dbo.OIC_SystemNotificationIns    Script Date: 3/2/2017 10:06:15 AM ******/

CREATE PROCEDURE [dbo].[OIC_SystemNotificationIns] 
	@MessageTypeId		TINYINT
	,@MessageContent	XML	
	
	,@UserId			INT
	,@Language			VARCHAR(10)	= 'E'
	,@IP				VARCHAR(50)	= NULL
	,@ErrCode			INT			= 0			OUTPUT
	,@ErrMsg			VARCHAR(300)= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150728
	Task: Insert system notification [Redmine:#40305]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20170302@Percy: Expand length of Content [RedmineID: #70322]
	
	Param's Explanation:
		@MessageContent	=	<root>
								<row EventId="1" LicenseeTypeId="0" LicenseeId="1" SubjectEn="subject1">
									<contentEn> ContentEn</contentEn>
								</row>
								<row EventId="2" LicenseeTypeId ="0" LicenseeId="1" SubjectEn="subject2">
									<contentEn> ContentEn</contentEn>
								</row>
							</root>
	*LicenseeTypeId <> 0 (LicenseeId = 0): ignore LicenseeId, send notification to all user belong to this TOL
	*LicenseeType = 0 (LicenseeId <> 0): send notification to all user belong to TOL of this licensee
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @startRun		DATETIME
			,@endRun		DATETIME
			,@duration		INT
			,@logSPData		NVARCHAR(MAX)
			,@xml			XML
			,@procName		VARCHAR(200)
			,@MessageId		INT	
			,@RowCount		INT = 0
			,@seq			INT = 1
			,@EventId		INT
			,@LicenseeId	INT
			,@LicenseeTypeId	TINYINT = 0
			,@IsTesting		BIT = 0	
			
	DECLARE @tblContent TABLE (seq INT IDENTITY(1,1), EventId INT, LicenseeTypeId TINYINT, LicenseeId INT, SubjectEn NVARCHAR(300), ContentEn NVARCHAR(MAX))
	DECLARE @tblUser TABLE (UserId INT)
	
	SET @startRun = GETDATE()
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE DisplayName LIKE 'starix%' AND UserId = @UserId)
		SET @IsTesting = 1
	
	INSERT INTO @tblContent (EventId, LicenseeTypeId, LicenseeId, SubjectEn, ContentEn)				
	SELECT	t.c.value('@EventId', 'INT')
			,t.c.value('@LicenseeTypeId', 'TINYINT')
			,t.c.value('@LicenseeId', 'INT')
			,t.c.value('@SubjectEn', 'NVARCHAR(300)')
			,t.c.value('.', 'NVARCHAR(4000)')
	FROM	@MessageContent.nodes('root/row') t(c)	
	OPTION (OPTIMIZE FOR (@MessageContent = NULL))
	
	SET @RowCount = @@rowcount
	
	WHILE (@seq <= @RowCount)
	BEGIN
		
		SELECT	@EventId		= EventId
				,@LicenseeId	= LicenseeId
				,@LicenseeTypeId = LicenseeTypeId
		FROM	@tblContent
		WHERE	seq = @seq
		
		IF @LicenseeTypeId = 0
		BEGIN
			SELECT	@LicenseeTypeId = LicenseeTypeId 
			FROM	dbo.Licensee WITH(NOLOCK)
			WHERE	LicenseeId = @LicenseeId
		END
		
		INSERT INTO @tblUser(UserId) 
		SELECT	@UserId	-- send notification for edited user & specific user's postion
		UNION 
		SELECT	UserId
		FROM	dbo.UserInfo WITH(NOLOCK)
		WHERE	PositionId IN (SELECT PositionId FROM dbo.f_PositionNotificationList(@EventId))
		UNION -- send notification for all internal user who has permission on licensee type of this licensee
		SELECT  UserId
		FROM	dbo.UserLicenseeType WITH(NOLOCK)
		WHERE	LicenseeTypeId = @LicenseeTypeId
		
		BEGIN TRY
			INSERT INTO dbo.Message (SubjectEn, ContentEn, MessageTypeId, Creator, CreateTime)
			SELECT	SubjectEn, ContentEn, @MessageTypeId, 0, GETDATE()		
			FROM	@tblContent
			WHERE	seq = @seq
			
			SET @MessageId = SCOPE_IDENTITY()
			
			INSERT INTO dbo.UserMessage(UserId, MessageId, IsRead)
			SELECT	t.UserId, @MessageId, 0
			FROM	@tblUser t
				INNER JOIN dbo.UserInfo u WITH(NOLOCK)
					ON t.UserId = u.UserId
			WHERE	(@IsTesting = 0
						OR (@IsTesting = 1 AND u.DisplayName LIKE 'starix%')) -- if the msg for testing, dont send to real user
			
			IF @IsTesting = 0 -- just insert msg into MessageTarget for real user
			BEGIN
				IF @LicenseeTypeId <> 0
				BEGIN
					INSERT INTO dbo.MessageTarget(LicenseeTypeId, MessageId, PositionId) VALUES (@LicenseeTypeId, @MessageId, 0)			
				END
				ELSE
				BEGIN
					INSERT INTO dbo.MessageTarget(LicenseeTypeId, MessageId, PositionId)
					SELECT	0, @MessageId, PositionId
					FROM	dbo.f_PositionNotificationList(@EventId)
				END
			END
		END TRY
		BEGIN CATCH
			DELETE FROM dbo.MessageTarget WITH(ROWLOCK, UPDLOCK)
			WHERE MessageId = @MessageId
			
			DELETE FROM dbo.UserMessage WITH(ROWLOCK, UPDLOCK)
			WHERE MessageId = @MessageId
			
			DELETE FROM dbo.Message WITH(ROWLOCK, UPDLOCK)
			WHERE MessageId = @MessageId
			
			SELECT	@Errcode = 100
					,@ErrMsg = dbo.f_Get_MsgNamebyMsgID(40000,@Language)
			
			RETURN
		END CATCH
		
		DELETE FROM @tblUser
		
		SET @seq = @seq + 1
	END
	
	-- write log
	SET @xml = (
		SELECT	@MessageTypeId AS '@mid'
				,@MessageContent
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT	@logSPData	= CONVERT(NVARCHAR(MAX),@xml)
			,@endRun		= GETDATE()  
			,@duration		= DATEDIFF(millisecond, @startRun, @endRun)   
			,@procName		= OBJECT_NAME(@@procid)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_SystemNotificationIns_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_SystemNotificationIns_xtest    Script Date: 3/2/2017 10:06:15 AM ******/

CREATE PROCEDURE [dbo].[OIC_SystemNotificationIns_xtest] 
	@MessageTypeId		TINYINT
	,@MessageContent	XML	
	
	,@UserId			INT
	,@Language			VARCHAR(10)	= 'E'
	,@IP				VARCHAR(50)	= NULL
	,@ErrCode			INT			= 0			OUTPUT
	,@ErrMsg			VARCHAR(300)= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150728
	Task: Insert system notification [Redmine:#40305]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20170302@Percy: Expand length of Content [RedmineID: #70322]
	
	Param's Explanation:
		@MessageContent	=	<root>
								<row EventId="1" LicenseeTypeId="0" LicenseeId="1" SubjectEn="subject1">
									<contentEn> ContentEn</contentEn>
								</row>
								<row EventId="2" LicenseeTypeId ="0" LicenseeId="1" SubjectEn="subject2">
									<contentEn> ContentEn</contentEn>
								</row>
							</root>
	*LicenseeTypeId <> 0 (LicenseeId = 0): ignore LicenseeId, send notification to all user belong to this TOL
	*LicenseeType = 0 (LicenseeId <> 0): send notification to all user belong to TOL of this licensee
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @startRun		DATETIME
			,@endRun		DATETIME
			,@duration		INT
			,@logSPData		NVARCHAR(MAX)
			,@xml			XML
			,@procName		VARCHAR(200)
			,@MessageId		INT	
			,@RowCount		INT = 0
			,@seq			INT = 1
			,@EventId		INT
			,@LicenseeId	INT
			,@LicenseeTypeId	TINYINT = 0
			,@IsTesting		BIT = 0	
			
	DECLARE @tblContent TABLE (seq INT IDENTITY(1,1), EventId INT, LicenseeTypeId TINYINT, LicenseeId INT, SubjectEn NVARCHAR(300), ContentEn NVARCHAR(MAX))
	DECLARE @tblUser TABLE (UserId INT)
	
	SET @startRun = GETDATE()
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE DisplayName LIKE 'starix%' AND UserId = @UserId)
		SET @IsTesting = 1
	
	INSERT INTO @tblContent (EventId, LicenseeTypeId, LicenseeId, SubjectEn, ContentEn)				
	SELECT	t.c.value('@EventId', 'INT')
			,t.c.value('@LicenseeTypeId', 'TINYINT')
			,t.c.value('@LicenseeId', 'INT')
			,t.c.value('@SubjectEn', 'NVARCHAR(300)')
			,t.c.value('.', 'NVARCHAR(4000)')
	FROM	@MessageContent.nodes('root/row') t(c)	
	OPTION (OPTIMIZE FOR (@MessageContent = NULL))
	
	SET @RowCount = @@rowcount
	
	WHILE (@seq <= @RowCount)
	BEGIN
		
		SELECT	@EventId		= EventId
				,@LicenseeId	= LicenseeId
				,@LicenseeTypeId = LicenseeTypeId
		FROM	@tblContent
		WHERE	seq = @seq
		
		IF @LicenseeTypeId = 0
		BEGIN
			SELECT	@LicenseeTypeId = LicenseeTypeId 
			FROM	dbo.Licensee WITH(NOLOCK)
			WHERE	LicenseeId = @LicenseeId
		END
		
		INSERT INTO @tblUser(UserId) 
		SELECT	@UserId	-- send notification for edited user & specific user's postion
		UNION 
		SELECT	UserId
		FROM	dbo.UserInfo WITH(NOLOCK)
		WHERE	PositionId IN (SELECT PositionId FROM dbo.f_PositionNotificationList(@EventId))
		UNION -- send notification for all internal user who has permission on licensee type of this licensee
		SELECT  UserId
		FROM	dbo.UserLicenseeType WITH(NOLOCK)
		WHERE	LicenseeTypeId = @LicenseeTypeId
		
		BEGIN TRY
			INSERT INTO dbo.Message (SubjectEn, ContentEn, MessageTypeId, Creator, CreateTime)
			SELECT	SubjectEn, ContentEn, @MessageTypeId, 0, GETDATE()		
			FROM	@tblContent
			WHERE	seq = @seq
			
			SET @MessageId = SCOPE_IDENTITY()
			
			INSERT INTO dbo.UserMessage(UserId, MessageId, IsRead)
			SELECT	t.UserId, @MessageId, 0
			FROM	@tblUser t
				INNER JOIN dbo.UserInfo u WITH(NOLOCK)
					ON t.UserId = u.UserId
			WHERE	(@IsTesting = 0
						OR (@IsTesting = 1 AND u.DisplayName LIKE 'starix%')) -- if the msg for testing, dont send to real user
			
			IF @IsTesting = 0 -- just insert msg into MessageTarget for real user
			BEGIN
				IF @LicenseeTypeId <> 0
				BEGIN
					INSERT INTO dbo.MessageTarget(LicenseeTypeId, MessageId, PositionId) VALUES (@LicenseeTypeId, @MessageId, 0)			
				END
				ELSE
				BEGIN
					INSERT INTO dbo.MessageTarget(LicenseeTypeId, MessageId, PositionId)
					SELECT	0, @MessageId, PositionId
					FROM	dbo.f_PositionNotificationList(@EventId)
				END
			END
		END TRY
		BEGIN CATCH
			DELETE FROM dbo.MessageTarget WITH(ROWLOCK, UPDLOCK)
			WHERE MessageId = @MessageId
			
			DELETE FROM dbo.UserMessage WITH(ROWLOCK, UPDLOCK)
			WHERE MessageId = @MessageId
			
			DELETE FROM dbo.Message WITH(ROWLOCK, UPDLOCK)
			WHERE MessageId = @MessageId
			
			SELECT	@Errcode = 100
					,@ErrMsg = dbo.f_Get_MsgNamebyMsgID(40000,@Language)
			
			RETURN
		END CATCH
		
		DELETE FROM @tblUser
		
		SET @seq = @seq + 1
	END
	
	-- write log
	SET @xml = (
		SELECT	@MessageTypeId AS '@mid'
				,@MessageContent
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT	@logSPData	= CONVERT(NVARCHAR(MAX),@xml)
			,@endRun		= GETDATE()  
			,@duration		= DATEDIFF(millisecond, @startRun, @endRun)   
			,@procName		= OBJECT_NAME(@@procid)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_TrainingRequestDel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_TrainingRequestDel    Script Date: 6/14/2017 10:35:09 PM ******/
/****** Object:  Stored Procedure dbo.OIC_TrainingRequestDel    Script Date: 6/13/2017 9:18:45 AM ******/

CREATE PROCEDURE [dbo].[OIC_TrainingRequestDel] 
	@TrainingRequestId		INT
	
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150618
	Task: delete training request [Redmine:#38086]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20170530@Percy: Change request on Training List [RedmineID: #74879]
		
	Param's Explanation:
	
 */
BEGIN
	SET NOCOUNT ON
	
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
		,@log_Attendee	XML
		
	SET @startRun = GETDATE()
	
	-- get data before update/delete
	SET @log_Attendee = (
							SELECT	AttendeeName		AS '@an'
									,AttendeePosition	AS '@ap'
									,AttendeeSkype		AS '@as'
							FROM	dbo.TrainingAttendee WITH(NOLOCK)
							WHERE	TrainingRequestId = @TrainingRequestId
							FOR XML PATH('row'), ROOT('a')		
						)
	SET @xml = (
		SELECT	l.LicenseeId		AS '@lid'
				,l.LicenseeName		AS '@ln'
				,LanguageUsed		AS '@lu'
				,TrainingDateUtc	AS '@td'
				,TimeZone			AS '@tz'
				,ts.TrainingStatusName	AS '@tsn'
				,tsd.TrainingStatusValue AS '@tsv'
				,@log_Attendee
		FROM	dbo.TrainingRequest t WITH(NOLOCK)
			INNER JOIN dbo.Licensee l WITH(NOLOCK) ON t.LicenseeId = l.LicenseeId
			INNER JOIN dbo.TrainingStatus ts WITH(NOLOCK) ON t.TrainingStatusId = ts.TrainingStatusId
			LEFT JOIN dbo.TrainingStatusDetail tsd WITH(NOLOCK) ON t.TrainingRequestId = tsd.TrainingRequestId
		WHERE t.TrainingRequestId = @TrainingRequestId
		FOR XML PATH('r'), TYPE
		)		
		
	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.TrainingRequest WITH(NOLOCK) WHERE TrainingRequestId = @TrainingRequestId)
		RETURN
	
	BEGIN TRY
		DELETE 
		FROM	dbo.TrainingAttendee WITH(ROWLOCK, UPDLOCK)
		WHERE	TrainingRequestId = @TrainingRequestId
		
		DELETE 
		FROM	dbo.TrainingRequest WITH(ROWLOCK, UPDLOCK)
		WHERE	TrainingRequestId = @TrainingRequestId

		DELETE 
		FROM	dbo.TrainingStatusDetail WITH(ROWLOCK, UPDLOCK)
		WHERE	TrainingRequestId = @TrainingRequestId
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 100
			,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1602,@Language) --  Fail to delete training. Please try again.
	
		RETURN
	END CATCH
	
	SELECT @logSPData	= CONVERT(NVARCHAR(MAX),@xml)
		,@endRun		= GETDATE()  
		,@duration		= DATEDIFF(millisecond, @startRun, @endRun)   
		,@procName		= OBJECT_NAME(@@procid)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= NULL
		,@OldData		= @logSPData
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_TrainingRequestDel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_TrainingRequestDel_xtest    Script Date: 6/13/2017 9:18:45 AM ******/

CREATE PROCEDURE [dbo].[OIC_TrainingRequestDel_xtest] 
	@TrainingRequestId		INT
	
	,@UserId				INT
	,@Language				VARCHAR(10)		= 'E'
	,@IP					VARCHAR(50)		= NULL
	,@ErrCode				INT				= 0			OUTPUT
	,@ErrMsg				VARCHAR(300)	= NULL		OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150618
	Task: delete training request [Redmine:#38086]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20170530@Percy: Change request on Training List [RedmineID: #74879]
		
	Param's Explanation:
	
 */
BEGIN
	SET NOCOUNT ON
	
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
		,@log_Attendee	XML
		
	SET @startRun = GETDATE()
	
	-- get data before update/delete
	SET @log_Attendee = (
							SELECT	AttendeeName		AS '@an'
									,AttendeePosition	AS '@ap'
									,AttendeeSkype		AS '@as'
							FROM	dbo.TrainingAttendee WITH(NOLOCK)
							WHERE	TrainingRequestId = @TrainingRequestId
							FOR XML PATH('row'), ROOT('a')		
						)
	SET @xml = (
		SELECT	l.LicenseeId		AS '@lid'
				,l.LicenseeName		AS '@ln'
				,LanguageUsed		AS '@lu'
				,TrainingDateUtc	AS '@td'
				,TimeZone			AS '@tz'
				,ts.TrainingStatusName	AS '@tsn'
				,tsd.TrainingStatusValue AS '@tsv'
				,@log_Attendee
		FROM	dbo.TrainingRequest t WITH(NOLOCK)
			INNER JOIN dbo.Licensee l WITH(NOLOCK) ON t.LicenseeId = l.LicenseeId
			INNER JOIN dbo.TrainingStatus ts WITH(NOLOCK) ON t.TrainingStatusId = ts.TrainingStatusId
			LEFT JOIN dbo.TrainingStatusDetail tsd WITH(NOLOCK) ON t.TrainingRequestId = tsd.TrainingRequestId
		WHERE t.TrainingRequestId = @TrainingRequestId
		FOR XML PATH('r'), TYPE
		)		
		
	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.TrainingRequest WITH(NOLOCK) WHERE TrainingRequestId = @TrainingRequestId)
		RETURN
	
	BEGIN TRY
		DELETE 
		FROM	dbo.TrainingAttendee WITH(ROWLOCK, UPDLOCK)
		WHERE	TrainingRequestId = @TrainingRequestId
		
		DELETE 
		FROM	dbo.TrainingRequest WITH(ROWLOCK, UPDLOCK)
		WHERE	TrainingRequestId = @TrainingRequestId

		DELETE 
		FROM	dbo.TrainingStatusDetail WITH(ROWLOCK, UPDLOCK)
		WHERE	TrainingRequestId = @TrainingRequestId
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 100
			,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1602,@Language) --  Fail to delete training. Please try again.
	
		RETURN
	END CATCH
	
	SELECT @logSPData	= CONVERT(NVARCHAR(MAX),@xml)
		,@endRun		= GETDATE()  
		,@duration		= DATEDIFF(millisecond, @startRun, @endRun)   
		,@procName		= OBJECT_NAME(@@procid)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= NULL
		,@OldData		= @logSPData
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_TrainingRequestIns]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_TrainingRequestIns    Script Date: 6/14/2017 10:35:09 PM ******/
/****** Object:  Stored Procedure dbo.OIC_TrainingRequestIns    Script Date: 6/13/2017 9:18:45 AM ******/

CREATE PROCEDURE [dbo].[OIC_TrainingRequestIns] 
	@SiteName				NVARCHAR(50)
	,@LanguageUsed			VARCHAR(30)
	,@TrainingDateUtc		DATETIME
	,@TimeZone				INT
	,@TrainingStatusId		TINYINT
	,@TrainingStatusValue	VARCHAR(50)		= NULL
	
	,@AttendeeList			XML
	
	,@UserId				INT
	,@IP					VARCHAR(50)		= NULL
	,@Language				VARCHAR(10)		= 'E'
	,@ErrCode				INT				= 0		OUTPUT
	,@ErrMsg				VARCHAR(300)	= ''	OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150617
	Task: Insert training request [Redmine:#38086]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20170530@Percy: Change request on Training List [RedmineID: #74879]
		
	Param's Explanation:
	@AttendeeList:	<root>
						<row AttendeeName="name" AttendeePosition="position" AttendeeSkype="skype" />
						<row AttendeeName="name" AttendeePosition="position" AttendeeSkype="skype" />
					</root>
 */
BEGIN
	SET NOCOUNT ON
	DECLARE @startRun				DATETIME
			,@endRun				DATETIME
			,@duration				INT
			,@logSPData				NVARCHAR(MAX)
			,@log_Attendee			XML
			,@xml					XML
			,@procName				VARCHAR(200)
			,@LicenseeId			INT
			,@TrainingRequestId		INT
			,@TrainingStatusName	VARCHAR(200)
			
	SET @startRun = GETDATE()
				
	-- check licensee name
	SELECT	@LicenseeId = LicenseeId 
	FROM	dbo.Licensee l WITH(NOLOCK) 
	INNER JOIN dbo.UserLicenseeType ul WITH(NOLOCK)
		ON	l.LicenseeTypeId = ul.LicenseeTypeId
			AND ul.UserId = @UserId
	WHERE	LicenseeName = @SiteName
	
	IF @@rowcount = 0
	BEGIN
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1603,@Language) -- Unable to create training because the entered site name is invalid or you are not authorized on this client.
            
        RETURN
	END
	
	BEGIN TRY
		INSERT INTO dbo.TrainingRequest (
				LicenseeId
				,LanguageUsed
				,TrainingDateUtc
				,TimeZone
				,TrainingStatusId
		)
		SELECT	@LicenseeId
				,@languageUsed
				,@TrainingDateUtc
				,@TimeZone
				,@TrainingStatusId
				
		SELECT	@TrainingRequestId = SCOPE_IDENTITY()
		
		INSERT INTO dbo.TrainingAttendee (
				TrainingRequestId
				,AttendeeName
				,AttendeePosition
				,AttendeeSkype
		)
		SELECT	@TrainingRequestId
				,t.c.value('@AttendeeName','NVARCHAR(50)') AS AttendeeName
				,t.c.value('@AttendeePosition', 'NVARCHAR(50)') AS AttendeePosition
				,t.c.value('@AttendeeSkype', 'NVARCHAR(50)') AS AttendeeSkype
		FROM	@AttendeeList.nodes('root/row') t(c)

		IF @TrainingStatusId = 5 --Available at
		BEGIN
			INSERT INTO dbo.TrainingStatusDetail (
				TrainingRequestId
				,TrainingStatusId
				,TrainingStatusValue
			)
			VALUES (
				@TrainingRequestId
				,@TrainingStatusId
				,@TrainingStatusValue
			)
		END
    
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 102
            ,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1600,@Language) --  Fail to create training. Please try again.
            
        RETURN
	END CATCH
	
	-- Write log
	SELECT @TrainingStatusName = TrainingStatusName
	FROM dbo.TrainingStatus WITH(NOLOCK)
	WHERE TrainingStatusId = @TrainingStatusId

	SET @log_Attendee = (
							SELECT	AttendeeName		AS '@an'
									,AttendeePosition	AS '@ap'
									,AttendeeSkype		AS '@as'
							FROM	dbo.TrainingAttendee WITH(NOLOCK)
							WHERE	TrainingRequestId = @TrainingRequestId
							FOR XML PATH('row'), ROOT('a')		
						)
	SET @xml = (
		SELECT	@LicenseeId			AS '@lid'
				,@SiteName			AS '@ln'
				,@LanguageUsed		AS '@lu'
				,@TrainingDateUtc	AS '@td'
				,@TimeZone			AS '@tz'
				,@TrainingStatusName AS '@tsn'
				,@TrainingStatusValue AS '@tsv'
				,@log_Attendee
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX),@xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(millisecond, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@procid)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_TrainingRequestIns_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_TrainingRequestIns_xtest    Script Date: 6/13/2017 9:18:45 AM ******/

CREATE PROCEDURE [dbo].[OIC_TrainingRequestIns_xtest] 
	@SiteName				NVARCHAR(50)
	,@LanguageUsed			VARCHAR(30)
	,@TrainingDateUtc		DATETIME
	,@TimeZone				INT
	,@TrainingStatusId		TINYINT
	,@TrainingStatusValue	VARCHAR(50)		= NULL
	
	,@AttendeeList			XML
	
	,@UserId				INT
	,@IP					VARCHAR(50)		= NULL
	,@Language				VARCHAR(10)		= 'E'
	,@ErrCode				INT				= 0		OUTPUT
	,@ErrMsg				VARCHAR(300)	= ''	OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150617
	Task: Insert training request [Redmine:#38086]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20170530@Percy: Change request on Training List [RedmineID: #74879]
		
	Param's Explanation:
	@AttendeeList:	<root>
						<row AttendeeName="name" AttendeePosition="position" AttendeeSkype="skype" />
						<row AttendeeName="name" AttendeePosition="position" AttendeeSkype="skype" />
					</root>
 */
BEGIN
	SET NOCOUNT ON
	DECLARE @startRun				DATETIME
			,@endRun				DATETIME
			,@duration				INT
			,@logSPData				NVARCHAR(MAX)
			,@log_Attendee			XML
			,@xml					XML
			,@procName				VARCHAR(200)
			,@LicenseeId			INT
			,@TrainingRequestId		INT
			,@TrainingStatusName	VARCHAR(200)
			
	SET @startRun = GETDATE()
				
	-- check licensee name
	SELECT	@LicenseeId = LicenseeId 
	FROM	dbo.Licensee l WITH(NOLOCK) 
	INNER JOIN dbo.UserLicenseeType ul WITH(NOLOCK)
		ON	l.LicenseeTypeId = ul.LicenseeTypeId
			AND ul.UserId = @UserId
	WHERE	LicenseeName = @SiteName
	
	IF @@rowcount = 0
	BEGIN
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1603,@Language) -- Unable to create training because the entered site name is invalid or you are not authorized on this client.
            
        RETURN
	END
	
	BEGIN TRY
		INSERT INTO dbo.TrainingRequest (
				LicenseeId
				,LanguageUsed
				,TrainingDateUtc
				,TimeZone
				,TrainingStatusId
		)
		SELECT	@LicenseeId
				,@languageUsed
				,@TrainingDateUtc
				,@TimeZone
				,@TrainingStatusId
				
		SELECT	@TrainingRequestId = SCOPE_IDENTITY()
		
		INSERT INTO dbo.TrainingAttendee (
				TrainingRequestId
				,AttendeeName
				,AttendeePosition
				,AttendeeSkype
		)
		SELECT	@TrainingRequestId
				,t.c.value('@AttendeeName','NVARCHAR(50)') AS AttendeeName
				,t.c.value('@AttendeePosition', 'NVARCHAR(50)') AS AttendeePosition
				,t.c.value('@AttendeeSkype', 'NVARCHAR(50)') AS AttendeeSkype
		FROM	@AttendeeList.nodes('root/row') t(c)

		IF @TrainingStatusId = 5 --Available at
		BEGIN
			INSERT INTO dbo.TrainingStatusDetail (
				TrainingRequestId
				,TrainingStatusId
				,TrainingStatusValue
			)
			VALUES (
				@TrainingRequestId
				,@TrainingStatusId
				,@TrainingStatusValue
			)
		END
    
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 102
            ,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1600,@Language) --  Fail to create training. Please try again.
            
        RETURN
	END CATCH
	
	-- Write log
	SELECT @TrainingStatusName = TrainingStatusName
	FROM dbo.TrainingStatus WITH(NOLOCK)
	WHERE TrainingStatusId = @TrainingStatusId

	SET @log_Attendee = (
							SELECT	AttendeeName		AS '@an'
									,AttendeePosition	AS '@ap'
									,AttendeeSkype		AS '@as'
							FROM	dbo.TrainingAttendee WITH(NOLOCK)
							WHERE	TrainingRequestId = @TrainingRequestId
							FOR XML PATH('row'), ROOT('a')		
						)
	SET @xml = (
		SELECT	@LicenseeId			AS '@lid'
				,@SiteName			AS '@ln'
				,@LanguageUsed		AS '@lu'
				,@TrainingDateUtc	AS '@td'
				,@TimeZone			AS '@tz'
				,@TrainingStatusName AS '@tsn'
				,@TrainingStatusValue AS '@tsv'
				,@log_Attendee
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX),@xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(millisecond, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@procid)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= NULL
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_TrainingRequestListSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_TrainingRequestListSel    Script Date: 6/14/2017 10:35:10 PM ******/
/****** Object:  Stored Procedure dbo.OIC_TrainingRequestListSel    Script Date: 6/13/2017 9:18:45 AM ******/

CREATE PROCEDURE [dbo].[OIC_TrainingRequestListSel] 
	@LicenseeName	NVARCHAR(50)	= ''
	,@AM			INT				= 0
	,@LanguageUsed	NVARCHAR(50)	= '%'
	,@FromDate		DATETIME		= NULL
	,@ToDate		DATETIME		= NULL
	,@StatusIdList	VARCHAR(100)	= 'All'
	
	,@UserId		INT
AS

/*
	Created by: Kathy
	Date: 20150617
	Task: List training request [Redmine:#38086]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20170530@Percy: add filter @AM - account manager and @StatusIdList - status of training [RedmineID: #74879]
	
	Param's Explanation:
		- @StatusIdList: multiple dropdown, StatusId from TrainingStatus table
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TrainingStatusId TABLE (StatusId TINYINT)

	IF @StatusIdList <> 'All'
	BEGIN
		INSERT INTO @TrainingStatusId (StatusId)
		SELECT CONVERT(TINYINT, val) FROM dbo.strSplit(@StatusIdList, ',')
	END

	SELECT	t.TrainingRequestId
			,t.TrainingDateUtc
			,l.LicenseeName
			,ui.DisplayName AS AccountManager
			,t.LanguageUsed
			,(SELECT COUNT(1) FROM dbo.TrainingAttendee ta WITH(NOLOCK) WHERE ta.TrainingRequestId = t.TrainingRequestId) AS NumberOfAttendee
			,ts.TrainingStatusName
			,tsd.TrainingStatusValue
	FROM	dbo.TrainingRequest t WITH(NOLOCK)
		INNER JOIN dbo.Licensee l WITH(NOLOCK) ON t.LicenseeId = l.LicenseeId
		INNER JOIN dbo.UserLicensee ul WITH(NOLOCK) ON l.LicenseeId = ul.LicenseeId
		INNER JOIN dbo.UserInfo ui WITH(NOLOCK) ON ul.UserId = ui.UserId
		INNER JOIN dbo.TrainingStatus ts WITH(NOLOCK) ON t.TrainingStatusId = ts.TrainingStatusId
		LEFT JOIN dbo.TrainingStatusDetail tsd WITH(NOLOCK) ON t.TrainingRequestId = tsd.TrainingRequestId
	WHERE	l.LicenseeName LIKE ISNULL(@LicenseeName,'%') + '%'
			AND t.LanguageUsed LIKE ISNULL(@LanguageUsed,'%') + '%'
			AND (t.TrainingDateUtc BETWEEN @FromDate AND @ToDate OR (@FromDate IS NULL AND @ToDate IS NULL))
			AND EXISTS (SELECT LicenseeTypeId FROM dbo.UserLicenseeType WITH(NOLOCK) WHERE LicenseeTypeId = l.LicenseeTypeId AND UserId = @UserId)
			AND ui.PositionId = 6 -- AM
			AND (
				@StatusIdList = 'All'
				OR ts.TrainingStatusId IN (SELECT StatusId FROM @TrainingStatusId)
			)
			AND (
				@AM = 0
				OR ui.UserId = @AM
			)
	ORDER BY t.TrainingDateUtc
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_TrainingRequestListSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_TrainingRequestListSel_xtest    Script Date: 6/13/2017 9:18:45 AM ******/

CREATE PROCEDURE [dbo].[OIC_TrainingRequestListSel_xtest] 
	@LicenseeName	NVARCHAR(50)	= ''
	,@AM			INT				= 0
	,@LanguageUsed	NVARCHAR(50)	= '%'
	,@FromDate		DATETIME		= NULL
	,@ToDate		DATETIME		= NULL
	,@StatusIdList	VARCHAR(100)	= 'All'
	
	,@UserId		INT
AS

/*
	Created by: Kathy
	Date: 20150617
	Task: List training request [Redmine:#38086]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20170530@Percy: add filter @AM - account manager and @StatusIdList - status of training [RedmineID: #74879]
	
	Param's Explanation:
		- @StatusIdList: multiple dropdown, StatusId from TrainingStatus table
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TrainingStatusId TABLE (StatusId TINYINT)

	IF @StatusIdList <> 'All'
	BEGIN
		INSERT INTO @TrainingStatusId (StatusId)
		SELECT CONVERT(TINYINT, val) FROM dbo.strSplit(@StatusIdList, ',')
	END

	SELECT	t.TrainingRequestId
			,t.TrainingDateUtc
			,l.LicenseeName
			,ui.DisplayName AS AccountManager
			,t.LanguageUsed
			,(SELECT COUNT(1) FROM dbo.TrainingAttendee ta WITH(NOLOCK) WHERE ta.TrainingRequestId = t.TrainingRequestId) AS NumberOfAttendee
			,ts.TrainingStatusName
			,tsd.TrainingStatusValue
	FROM	dbo.TrainingRequest t WITH(NOLOCK)
		INNER JOIN dbo.Licensee l WITH(NOLOCK) ON t.LicenseeId = l.LicenseeId
		INNER JOIN dbo.UserLicensee ul WITH(NOLOCK) ON l.LicenseeId = ul.LicenseeId
		INNER JOIN dbo.UserInfo ui WITH(NOLOCK) ON ul.UserId = ui.UserId
		INNER JOIN dbo.TrainingStatus ts WITH(NOLOCK) ON t.TrainingStatusId = ts.TrainingStatusId
		LEFT JOIN dbo.TrainingStatusDetail tsd WITH(NOLOCK) ON t.TrainingRequestId = tsd.TrainingRequestId
	WHERE	l.LicenseeName LIKE ISNULL(@LicenseeName,'%') + '%'
			AND t.LanguageUsed LIKE ISNULL(@LanguageUsed,'%') + '%'
			AND (t.TrainingDateUtc BETWEEN @FromDate AND @ToDate OR (@FromDate IS NULL AND @ToDate IS NULL))
			AND EXISTS (SELECT LicenseeTypeId FROM dbo.UserLicenseeType WITH(NOLOCK) WHERE LicenseeTypeId = l.LicenseeTypeId AND UserId = @UserId)
			AND ui.PositionId = 6 -- AM
			AND (
				@StatusIdList = 'All'
				OR ts.TrainingStatusId IN (SELECT StatusId FROM @TrainingStatusId)
			)
			AND (
				@AM = 0
				OR ui.UserId = @AM
			)
	ORDER BY t.TrainingDateUtc
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_TrainingRequestSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_TrainingRequestSel    Script Date: 6/14/2017 10:35:11 PM ******/
/****** Object:  Stored Procedure dbo.OIC_TrainingRequestSel    Script Date: 6/13/2017 9:18:45 AM ******/

CREATE PROCEDURE [dbo].[OIC_TrainingRequestSel] 
	@TrainingRequestId		INT
AS
/*
	Created by: Kathy
	Date: 20150618
	Task: select training request info [Redmine:#38086]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20170530@Percy: Change request on Training List [RedmineID: #74879]
		
	Param's Explanation:
	
 */
BEGIN
	SET NOCOUNT ON
	
	SELECT	l.LicenseeName
			,ui.DisplayName
			,t.LanguageUsed
			,t.TrainingDateUtc
			,t.TimeZone
			,ts.TrainingStatusId
			,ts.TrainingStatusName
			,tsd.TrainingStatusValue
	FROM	dbo.TrainingRequest t WITH(NOLOCK)
		INNER JOIN dbo.Licensee l WITH(NOLOCK) ON t.LicenseeId = l.LicenseeId
		INNER JOIN dbo.UserLicensee ul WITH(NOLOCK) ON l.LicenseeId = ul.LicenseeId
		INNER JOIN dbo.UserInfo ui WITH(NOLOCK) ON ul.UserId = ui.UserId AND ui.PositionId = 6
		INNER JOIN dbo.TrainingStatus ts WITH(NOLOCK) ON t.TrainingStatusId = ts.TrainingStatusId
		LEFT JOIN dbo.TrainingStatusDetail tsd WITH(NOLOCK) ON t.TrainingRequestId = tsd.TrainingRequestId
	WHERE t.TrainingRequestId = @TrainingRequestId
	
	SELECT	AttendeeName
			,AttendeePosition
			,AttendeeSkype
	FROM	dbo.TrainingAttendee WITH(NOLOCK)
	WHERE	TrainingRequestId = @TrainingRequestId
	ORDER BY AttendeeId
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_TrainingRequestSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_TrainingRequestSel_xtest    Script Date: 6/13/2017 9:18:45 AM ******/

CREATE PROCEDURE [dbo].[OIC_TrainingRequestSel_xtest] 
	@TrainingRequestId		INT
AS
/*
	Created by: Kathy
	Date: 20150618
	Task: select training request info [Redmine:#38086]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20170530@Percy: Change request on Training List [RedmineID: #74879]
		
	Param's Explanation:
	
 */
BEGIN
	SET NOCOUNT ON
	
	SELECT	l.LicenseeName
			,ui.DisplayName
			,t.LanguageUsed
			,t.TrainingDateUtc
			,t.TimeZone
			,ts.TrainingStatusId
			,ts.TrainingStatusName
			,tsd.TrainingStatusValue
	FROM	dbo.TrainingRequest t WITH(NOLOCK)
		INNER JOIN dbo.Licensee l WITH(NOLOCK) ON t.LicenseeId = l.LicenseeId
		INNER JOIN dbo.UserLicensee ul WITH(NOLOCK) ON l.LicenseeId = ul.LicenseeId
		INNER JOIN dbo.UserInfo ui WITH(NOLOCK) ON ul.UserId = ui.UserId AND ui.PositionId = 6
		INNER JOIN dbo.TrainingStatus ts WITH(NOLOCK) ON t.TrainingStatusId = ts.TrainingStatusId
		LEFT JOIN dbo.TrainingStatusDetail tsd WITH(NOLOCK) ON t.TrainingRequestId = tsd.TrainingRequestId
	WHERE t.TrainingRequestId = @TrainingRequestId
	
	SELECT	AttendeeName
			,AttendeePosition
			,AttendeeSkype
	FROM	dbo.TrainingAttendee WITH(NOLOCK)
	WHERE	TrainingRequestId = @TrainingRequestId
	ORDER BY AttendeeId
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_TrainingRequestUpd]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_TrainingRequestUpd    Script Date: 6/14/2017 10:35:12 PM ******/
/****** Object:  Stored Procedure dbo.OIC_TrainingRequestUpd    Script Date: 6/13/2017 9:18:45 AM ******/

CREATE PROCEDURE [dbo].[OIC_TrainingRequestUpd] 
	@TrainingRequestId		INT
	,@LanguageUsed			VARCHAR(30)
	,@TrainingDateUtc		DATETIME
	,@TimeZone				INT
	,@TrainingStatusId		TINYINT
	,@TrainingStatusValue	VARCHAR(50)		= NULL
	
	,@AttendeeList			XML
	
	,@UserId				INT
	,@IP					VARCHAR(50)		= NULL
	,@Language				VARCHAR(10)		= 'E'
	,@ErrCode				INT				= 0		OUTPUT
	,@ErrMsg				VARCHAR(300)	= ''	OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150617
	Task: Update training request [Redmine:#38086]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20170530@Percy: Change request on Training List [RedmineID: #74879]
	
	Param's Explanation:
		@AttendeeList:	<root>
							<row AttendeeName="name" AttendeePosition="position" AttendeeSkype="skype" />
							<row AttendeeName="name" AttendeePosition="position" AttendeeSkype="skype" />
						</root>
		
 */
BEGIN
	SET NOCOUNT ON
	DECLARE @startRun				DATETIME
			,@endRun				DATETIME
			,@duration				INT
			,@logSPData				NVARCHAR(MAX)
			,@logSPOldData			NVARCHAR(MAX)
			,@xml					XML
			,@procName				VARCHAR(200)
			,@SiteName				NVARCHAR(50)
			,@oldLog_Attendee		XML
			,@log_Attendee			XML
			
	DECLARE @tblTrainingAttendee TABLE (
			RowNumber INT IDENTITY (1,1)
			,AttendeeName NVARCHAR(50)
			,AttendeePosition NVARCHAR(50)
			,AttendeeSkype NVARCHAR(50)
	)
	
	SET @startRun = GETDATE()
	
	-- get data before update/insert
	SET @oldLog_Attendee = (
						SELECT	AttendeeName		AS '@an'
								,AttendeePosition	AS '@ap'
								,AttendeeSkype		AS '@as'
						FROM	dbo.TrainingAttendee WITH(NOLOCK)
						WHERE	TrainingRequestId = @TrainingRequestId
						FOR XML PATH('row'), ROOT('a')		
					)
	
	SET @xml = (
		SELECT	l.LicenseeId		AS '@lid'
				,l.LicenseeName		AS '@ln'
				,LanguageUsed		AS '@lu'
				,TrainingDateUtc	AS '@td'
				,TimeZone			AS '@tz'
				,ts.TrainingStatusName	AS '@tsn'
				,tsd.TrainingStatusValue AS '@tsv'
				,@oldLog_Attendee
		FROM	dbo.TrainingRequest t WITH(NOLOCK)
			INNER JOIN dbo.Licensee l WITH(NOLOCK) ON t.LicenseeId = l.LicenseeId
			INNER JOIN dbo.TrainingStatus ts WITH(NOLOCK) ON t.TrainingStatusId = ts.TrainingStatusId
			LEFT JOIN dbo.TrainingStatusDetail tsd WITH(NOLOCK) ON t.TrainingRequestId = tsd.TrainingRequestId
		WHERE t.TrainingRequestId = @TrainingRequestId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPOldData = CONVERT(NVARCHAR(MAX),@xml)
									
	BEGIN TRY
		UPDATE	dbo.TrainingRequest WITH(ROWLOCK, UPDLOCK)
			SET LanguageUsed	= @LanguageUsed
				,TrainingDateUtc= @TrainingDateUtc
				,TimeZone		= @TimeZone
				,TrainingStatusId = @TrainingStatusId
		WHERE	TrainingRequestId = @TrainingRequestId		
		
		INSERT INTO @tblTrainingAttendee (
				AttendeeName
				,AttendeePosition
				,AttendeeSkype
		)
		SELECT	t.c.value('@AttendeeName','NVARCHAR(50)') AS AttendeeName
				,t.c.value('@AttendeePosition', 'NVARCHAR(50)') AS AttendeePosition
				,t.c.value('@AttendeeSkype', 'NVARCHAR(50)') AS AttendeeSkype
		FROM	@AttendeeList.nodes('root/row') t(c)
    
		;WITH tmpTrainingAttendee
		AS
		(
			SELECT	ROW_NUMBER() OVER (ORDER BY AttendeeId) AS RowNumber
					,TrainingRequestId
					,AttendeeName
					,AttendeePosition
					,AttendeeSkype
			FROM	dbo.TrainingAttendee WITH(NOLOCK)
			WHERE	TrainingRequestId = @TrainingRequestId
		)
		
		MERGE	tmpTrainingAttendee AS ta
		USING	(SELECT RowNumber, AttendeeName, AttendeePosition, AttendeeSkype FROM @tblTrainingAttendee) AS t
			ON	ta.RowNumber = t.RowNumber
		WHEN MATCHED AND (ta.AttendeeName <> t.AttendeeName	OR ta.AttendeePosition <> t.AttendeePosition OR ta.AttendeeSkype <> t.AttendeeSkype) 
					THEN UPDATE SET ta.AttendeeName = t.AttendeeName, ta.AttendeePosition = t.AttendeePosition, ta.AttendeeSkype = t.AttendeeSkype
		WHEN NOT MATCHED BY TARGET THEN INSERT (TrainingRequestId, AttendeeName, AttendeePosition, AttendeeSkype) VALUES (@TrainingRequestId, t.AttendeeName, t.AttendeePosition, t.AttendeeSkype)																				
		WHEN NOT MATCHED BY SOURCE THEN DELETE;

		IF @TrainingStatusId = 5 -- Available at
		BEGIN
			UPDATE dbo.TrainingStatusDetail WITH(ROWLOCK, UPDLOCK)
			SET TrainingStatusId = 5, TrainingStatusValue = @TrainingStatusValue
			WHERE TrainingRequestId = @TrainingRequestId

			IF @@ROWCOUNT = 0
			BEGIN
				INSERT INTO dbo.TrainingStatusDetail (TrainingRequestId, TrainingStatusId, TrainingStatusValue)
				VALUES (@TrainingRequestId, @TrainingStatusId, @TrainingStatusValue)
			END
		END
		ELSE
		BEGIN
			DELETE dbo.TrainingStatusDetail WITH(ROWLOCK, UPDLOCK)
			WHERE TrainingRequestId = @TrainingRequestId
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 101
            ,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1601,@Language) --  Fail to edit training. Please try again.
            
        RETURN
	END CATCH
	
	-- Write log	
	SET @log_Attendee = (
							SELECT	AttendeeName		AS '@an'
									,AttendeePosition	AS '@ap'
									,AttendeeSkype		AS '@as'
							FROM	dbo.TrainingAttendee WITH(NOLOCK)
							WHERE	TrainingRequestId = @TrainingRequestId
							FOR XML PATH('row'), ROOT('a')		
						)
					
	SET @xml = (
		SELECT	l.LicenseeId		AS '@lid'
				,l.LicenseeName		AS '@ln'
				,LanguageUsed		AS '@lu'
				,TrainingDateUtc	AS '@td'
				,TimeZone			AS '@tz'
				,ts.TrainingStatusName	AS '@tsn'
				,tsd.TrainingStatusValue AS '@tsv'
				,@log_Attendee
		FROM	dbo.TrainingRequest t WITH(NOLOCK)
			INNER JOIN dbo.Licensee l WITH(NOLOCK) ON t.LicenseeId = l.LicenseeId
			INNER JOIN dbo.TrainingStatus ts WITH(NOLOCK) ON t.TrainingStatusId = ts.TrainingStatusId
			LEFT JOIN dbo.TrainingStatusDetail tsd WITH(NOLOCK) ON t.TrainingRequestId = tsd.TrainingRequestId
		WHERE t.TrainingRequestId = @TrainingRequestId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData	= CONVERT(NVARCHAR(MAX),@xml)
		,@endRun		= GETDATE()  
		,@duration		= DATEDIFF(millisecond, @startRun, @endRun)   
		,@procName		= OBJECT_NAME(@@procid)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOldData
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_TrainingRequestUpd_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_TrainingRequestUpd_xtest    Script Date: 6/13/2017 9:18:45 AM ******/

CREATE PROCEDURE [dbo].[OIC_TrainingRequestUpd_xtest] 
	@TrainingRequestId		INT
	,@LanguageUsed			VARCHAR(30)
	,@TrainingDateUtc		DATETIME
	,@TimeZone				INT
	,@TrainingStatusId		TINYINT
	,@TrainingStatusValue	VARCHAR(50)		= NULL
	
	,@AttendeeList			XML
	
	,@UserId				INT
	,@IP					VARCHAR(50)		= NULL
	,@Language				VARCHAR(10)		= 'E'
	,@ErrCode				INT				= 0		OUTPUT
	,@ErrMsg				VARCHAR(300)	= ''	OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150617
	Task: Update training request [Redmine:#38086]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20170530@Percy: Change request on Training List [RedmineID: #74879]
	
	Param's Explanation:
		@AttendeeList:	<root>
							<row AttendeeName="name" AttendeePosition="position" AttendeeSkype="skype" />
							<row AttendeeName="name" AttendeePosition="position" AttendeeSkype="skype" />
						</root>
		
 */
BEGIN
	SET NOCOUNT ON
	DECLARE @startRun				DATETIME
			,@endRun				DATETIME
			,@duration				INT
			,@logSPData				NVARCHAR(MAX)
			,@logSPOldData			NVARCHAR(MAX)
			,@xml					XML
			,@procName				VARCHAR(200)
			,@SiteName				NVARCHAR(50)
			,@oldLog_Attendee		XML
			,@log_Attendee			XML
			
	DECLARE @tblTrainingAttendee TABLE (
			RowNumber INT IDENTITY (1,1)
			,AttendeeName NVARCHAR(50)
			,AttendeePosition NVARCHAR(50)
			,AttendeeSkype NVARCHAR(50)
	)
	
	SET @startRun = GETDATE()
	
	-- get data before update/insert
	SET @oldLog_Attendee = (
						SELECT	AttendeeName		AS '@an'
								,AttendeePosition	AS '@ap'
								,AttendeeSkype		AS '@as'
						FROM	dbo.TrainingAttendee WITH(NOLOCK)
						WHERE	TrainingRequestId = @TrainingRequestId
						FOR XML PATH('row'), ROOT('a')		
					)
	
	SET @xml = (
		SELECT	l.LicenseeId		AS '@lid'
				,l.LicenseeName		AS '@ln'
				,LanguageUsed		AS '@lu'
				,TrainingDateUtc	AS '@td'
				,TimeZone			AS '@tz'
				,ts.TrainingStatusName	AS '@tsn'
				,tsd.TrainingStatusValue AS '@tsv'
				,@oldLog_Attendee
		FROM	dbo.TrainingRequest t WITH(NOLOCK)
			INNER JOIN dbo.Licensee l WITH(NOLOCK) ON t.LicenseeId = l.LicenseeId
			INNER JOIN dbo.TrainingStatus ts WITH(NOLOCK) ON t.TrainingStatusId = ts.TrainingStatusId
			LEFT JOIN dbo.TrainingStatusDetail tsd WITH(NOLOCK) ON t.TrainingRequestId = tsd.TrainingRequestId
		WHERE t.TrainingRequestId = @TrainingRequestId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPOldData = CONVERT(NVARCHAR(MAX),@xml)
									
	BEGIN TRY
		UPDATE	dbo.TrainingRequest WITH(ROWLOCK, UPDLOCK)
			SET LanguageUsed	= @LanguageUsed
				,TrainingDateUtc= @TrainingDateUtc
				,TimeZone		= @TimeZone
				,TrainingStatusId = @TrainingStatusId
		WHERE	TrainingRequestId = @TrainingRequestId		
		
		INSERT INTO @tblTrainingAttendee (
				AttendeeName
				,AttendeePosition
				,AttendeeSkype
		)
		SELECT	t.c.value('@AttendeeName','NVARCHAR(50)') AS AttendeeName
				,t.c.value('@AttendeePosition', 'NVARCHAR(50)') AS AttendeePosition
				,t.c.value('@AttendeeSkype', 'NVARCHAR(50)') AS AttendeeSkype
		FROM	@AttendeeList.nodes('root/row') t(c)
    
		;WITH tmpTrainingAttendee
		AS
		(
			SELECT	ROW_NUMBER() OVER (ORDER BY AttendeeId) AS RowNumber
					,TrainingRequestId
					,AttendeeName
					,AttendeePosition
					,AttendeeSkype
			FROM	dbo.TrainingAttendee WITH(NOLOCK)
			WHERE	TrainingRequestId = @TrainingRequestId
		)
		
		MERGE	tmpTrainingAttendee AS ta
		USING	(SELECT RowNumber, AttendeeName, AttendeePosition, AttendeeSkype FROM @tblTrainingAttendee) AS t
			ON	ta.RowNumber = t.RowNumber
		WHEN MATCHED AND (ta.AttendeeName <> t.AttendeeName	OR ta.AttendeePosition <> t.AttendeePosition OR ta.AttendeeSkype <> t.AttendeeSkype) 
					THEN UPDATE SET ta.AttendeeName = t.AttendeeName, ta.AttendeePosition = t.AttendeePosition, ta.AttendeeSkype = t.AttendeeSkype
		WHEN NOT MATCHED BY TARGET THEN INSERT (TrainingRequestId, AttendeeName, AttendeePosition, AttendeeSkype) VALUES (@TrainingRequestId, t.AttendeeName, t.AttendeePosition, t.AttendeeSkype)																				
		WHEN NOT MATCHED BY SOURCE THEN DELETE;

		IF @TrainingStatusId = 5 -- Available at
		BEGIN
			UPDATE dbo.TrainingStatusDetail WITH(ROWLOCK, UPDLOCK)
			SET TrainingStatusId = 5, TrainingStatusValue = @TrainingStatusValue
			WHERE TrainingRequestId = @TrainingRequestId

			IF @@ROWCOUNT = 0
			BEGIN
				INSERT INTO dbo.TrainingStatusDetail (TrainingRequestId, TrainingStatusId, TrainingStatusValue)
				VALUES (@TrainingRequestId, @TrainingStatusId, @TrainingStatusValue)
			END
		END
		ELSE
		BEGIN
			DELETE dbo.TrainingStatusDetail WITH(ROWLOCK, UPDLOCK)
			WHERE TrainingRequestId = @TrainingRequestId
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 101
            ,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](1601,@Language) --  Fail to edit training. Please try again.
            
        RETURN
	END CATCH
	
	-- Write log	
	SET @log_Attendee = (
							SELECT	AttendeeName		AS '@an'
									,AttendeePosition	AS '@ap'
									,AttendeeSkype		AS '@as'
							FROM	dbo.TrainingAttendee WITH(NOLOCK)
							WHERE	TrainingRequestId = @TrainingRequestId
							FOR XML PATH('row'), ROOT('a')		
						)
					
	SET @xml = (
		SELECT	l.LicenseeId		AS '@lid'
				,l.LicenseeName		AS '@ln'
				,LanguageUsed		AS '@lu'
				,TrainingDateUtc	AS '@td'
				,TimeZone			AS '@tz'
				,ts.TrainingStatusName	AS '@tsn'
				,tsd.TrainingStatusValue AS '@tsv'
				,@log_Attendee
		FROM	dbo.TrainingRequest t WITH(NOLOCK)
			INNER JOIN dbo.Licensee l WITH(NOLOCK) ON t.LicenseeId = l.LicenseeId
			INNER JOIN dbo.TrainingStatus ts WITH(NOLOCK) ON t.TrainingStatusId = ts.TrainingStatusId
			LEFT JOIN dbo.TrainingStatusDetail tsd WITH(NOLOCK) ON t.TrainingRequestId = tsd.TrainingRequestId
		WHERE t.TrainingRequestId = @TrainingRequestId
		FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData	= CONVERT(NVARCHAR(MAX),@xml)
		,@endRun		= GETDATE()  
		,@duration		= DATEDIFF(millisecond, @startRun, @endRun)   
		,@procName		= OBJECT_NAME(@@procid)

	EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOldData
		,@Duration		= @Duration
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_TrainingStatusListSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_TrainingStatusListSel    Script Date: 6/14/2017 10:35:16 PM ******/
/****** Object:  Stored Procedure dbo.OIC_TrainingStatusListSel    Script Date: 6/13/2017 9:18:45 AM ******/

CREATE PROCEDURE [dbo].[OIC_TrainingStatusListSel] 
AS

/*
	Created by Percy
	Date: 2017-05-30
	DB: DBOIC.bodb_OIC
	Task: Select status of training [RedmineID: #74879]

	Revisions:
*/

BEGIN
	SET NOCOUNT ON

	SELECT TrainingStatusId, TrainingStatusName
	FROM dbo.TrainingStatus WITH(NOLOCK)
	ORDER BY TrainingStatusId
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_TrainingStatusListSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_TrainingStatusListSel_xtest    Script Date: 6/13/2017 9:18:45 AM ******/

CREATE PROCEDURE [dbo].[OIC_TrainingStatusListSel_xtest] 
AS

/*
	Created by Percy
	Date: 2017-05-30
	DB: DBOIC.bodb_OIC
	Task: Select status of training [RedmineID: #74879]

	Revisions:
*/

BEGIN
	SET NOCOUNT ON

	SELECT TrainingStatusId, TrainingStatusName
	FROM dbo.TrainingStatus WITH(NOLOCK)
	ORDER BY TrainingStatusId
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_UserDisplayNameSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_UserDisplayNameSel    Script Date: 21/10/2015 12:37:03 PM ******/
CREATE PROCEDURE [dbo].[OIC_UserDisplayNameSel] 
	@UserId INT
AS
/*
	Created by: Kathy
	Date: 20151012
	Task: select display name
	DB: DBOIC.bodb_OIC
	
	Revisions:
		
	Param's Explanation:
	
				
 */
BEGIN
	SET NOCOUNT ON

	SELECT	DisplayName
	FROM	dbo.UserInfo WITH(NOLOCK)
	WHERE	UserId = @UserId
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_UserFirstLoginChecking]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_UserFirstLoginChecking    Script Date: 03/08/2015 3:10:29 PM ******/
CREATE PROCEDURE [dbo].[OIC_UserFirstLoginChecking] 
	@UserId			INT
	,@IsFirstLogin	BIT		= 0		OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150617
	Task: checking whether it's first login or not [Redmine:#38087]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	Param's Explanation:
		
		
 */
BEGIN
	SET NOCOUNT ON
				
	IF ISNULL((SELECT Email FROM dbo.UserInfo WITH(NOLOCK) WHERE UserId = @UserId),'') = ''
		SET @IsFirstLogin = 1
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_UserInfoListSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_UserInfoListSel    Script Date: 03/08/2015 3:10:30 PM ******/
CREATE PROCEDURE [dbo].[OIC_UserInfoListSel] 
	@DisplayName			NVARCHAR(50)	= '%'
	,@SelectedPosition		VARCHAR(100)	= 'All'
	,@SelectedLicenseeType	VARCHAR(100)	= 'All'
	,@PageSize				INT				= 10
	,@PageIndex				INT				= 0 
	,@TotalRecords			INT				= 0		OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150618
	Task: list user [Redmine:#38088]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	Param's Explanation:
		
		
 */
BEGIN
	SET NOCOUNT ON
	DECLARE @RowStart		INT
			,@RowEnd		INT
			
	SELECT	ROW_NUMBER() OVER(ORDER BY DisplayName) AS RowNumber
			,u.UserId
			,u.DisplayName
			,(SELECT PositionName FROM dbo.Position WITH(NOLOCK) WHERE PositionId =  u.PositionId) AS PositionName
			,STUFF(
					(SELECT	',' + lt.LicenseeTypeName
					FROM	dbo.UserLicenseeType ult WITH(NOLOCK)
						INNER JOIN dbo.LicenseeType lt WITH(NOLOCK) 
							ON	lt.LicenseeTypeId = ult.LicenseeTypeId
					WHERE	ult.UserId = u.UserId
					FOR XML PATH('')),1,1,''
			) AS LicenseeType
			,u.Email
			,u.Skype
			,u.PhoneNumber
			,u.Remark
	INTO	#tmpResult
	FROM	dbo.UserInfo u WITH(NOLOCK)
	WHERE	u.DisplayName LIKE ISNULL(@DisplayName,'%') + '%'
			AND (@SelectedPosition = 'All' OR u.PositionId IN (SELECT val FROM dbo.strSplit(@SelectedPosition,',')))
			AND EXISTS (SELECT	LicenseeTypeId 
						FROM	UserLicenseeType ult WITH(NOLOCK) 
						WHERE	u.UserId = ult.UserId 
								AND (@SelectedLicenseeType = 'All' 
										OR (ult.LicenseeTypeId IN (SELECT val FROM dbo.strSplit(@SelectedLicenseeType,',')))
									) 
						)			
	
	SELECT @TotalRecords = @@rowcount
	
	SELECT	@PageIndex	= @PageIndex 
			,@RowStart		= @PageSize * @PageIndex + 1
			,@RowEnd		= @RowStart + @PageSize - 1
	
	SELECT	UserId
			,DisplayName
			,PositionName
			,LicenseeType
			,Email
			,Skype
			,PhoneNumber
			,Remark
	FROM	#tmpResult
	WHERE	RowNumber BETWEEN @RowStart AND @RowEnd		
			
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_UserInfoSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_UserInfoSel    Script Date: 03/08/2015 3:10:29 PM ******/
CREATE PROCEDURE [dbo].[OIC_UserInfoSel] 
	@UserId			INT
AS
/*
	Created by: Kathy
	Date: 20150617
	Task: select user info [Redmine:#38087]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	Param's Explanation:
		
		
 */
BEGIN
	SET NOCOUNT ON

	SELECT	ci.username AS UserName
			,DisplayName
			,u.PositionId
			,(SELECT PositionName FROM dbo.Position WITH(NOLOCK) WHERE PositionId = u.PositionId) AS PositionName
			,CompanyName
			,JoinedDate
			,CountryName
			,Email
			,PhoneNumber
			,Skype
			,Line
			,Remark
	FROM	dbo.UserInfo u WITH(NOLOCK)		
		INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK)
			ON	ci.custid = u.UserId
	WHERE	UserId = @UserId
	
	;WITH tmpUserLicensee
	AS (
		SELECT	l.LicenseeTypeId				
				,l.LicenseeName
		FROM	dbo.UserLicensee ul WITH(NOLOCK)
			INNER JOIN dbo.Licensee l WITH(NOLOCK)
				ON	l.LicenseeId = ul.LicenseeId AND ul.UserId = @UserId
		)
	SELECT	ult.LicenseeTypeId
			,lt.LicenseeTypeName
			,STUFF((
				SELECT ',' + t.licenseename
				FROM tmpUserLicensee t
				WHERE t.licenseetypeid = ult.LicenseeTypeId
				FOR XML PATH('')
				), 1, 1, '') AS LicenseeNames
	FROM	dbo.UserLicenseeType ult WITH(NOLOCK)
		INNER JOIN dbo.LicenseeType lt WITH(NOLOCK)
			ON	lt.LicenseeTypeId = ult.LicenseeTypeId AND ult.UserId = @UserId
	ORDER BY lt.LicenseeTypeId
	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_UserInfoUpd]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_UserInfoUpd    Script Date: 11/21/2016 10:54:10 PM ******/
/****** Object:  Stored Procedure dbo.OIC_UserInfoUpd    Script Date: 11/11/2016 10:29:58 AM ******/

CREATE PROCEDURE [dbo].[OIC_UserInfoUpd] 
	@UserId			INT
	,@DisplayName	NVARCHAR(50)
	,@CompanyName	NVARCHAR(50)	= NULL
	,@PositionId	TINYINT
	,@JoinedDate	DATETIME
	,@CountryName	NVARCHAR(50)
	,@Email			VARCHAR(50)
	,@PhoneNumber	VARCHAR(50)
	,@Skype			VARCHAR(50)		= NULL
	,@Line			VARCHAR(50)		= NULL
	,@Remark		NVARCHAR(300)	= NULL
	
	,@IP			VARCHAR(50)		= NULL
	,@Language		VARCHAR(10)		= 'E'
	,@ErrCode		INT				= 0		OUTPUT
	,@ErrMsg		VARCHAR(300)	= ''	OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150617
	Task: update user profile [Redmine:#38087]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160808@Percy: Update Default Email when first login [RedmineID: #61904]
	
	Param's Explanation:
		
		
 */
BEGIN
	SET NOCOUNT ON
				
	DECLARE @startRun			DATETIME
			,@endRun			DATETIME
			,@duration			INT
			,@logSPData			NVARCHAR(MAX)
			,@logSPOldData		NVARCHAR(MAX)
			,@xml				XML
			,@procName			VARCHAR(200)

			,@IsFirstLogin		BIT				= 0
			
	SET @startRun = GETDATE()	
	
	-- get data before update/insert		
	SET @xml = (
				SELECT	@UserId			AS '@uid'
						,DisplayName	AS '@udn'
						,CompanyName	AS '@ucomn'
						,p.PositionId	AS '@upi'
						,p.PositionName	AS '@upn'
						,JoinedDate		AS '@ujd'
						,CountryName	AS '@ucoun'
						,Email			AS '@ue'
						,PhoneNumber	AS '@up'
						,Skype			AS '@us'
						,Line			AS '@ul'
						,Remark			AS '@ur'
						,@IsFirstLogin	AS '@fl'
				FROM	dbo.UserInfo u WITH(NOLOCK)
					INNER JOIN dbo.Position p WITH(NOLOCK) ON u.PositionId = p.PositionId
				WHERE	UserId = @UserId
				FOR XML PATH('r'), TYPE
	)
	
	SELECT @logSPOldData = CONVERT(NVARCHAR(MAX),@xml)
	
	-- checking display name
	IF EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE DisplayName = @DisplayName AND UserId <> @UserId)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](20001,@Language) --   Display name exists.
            
        RETURN
	END
	
	-- checking first login or not
	EXEC dbo.OIC_UserFirstLoginChecking 
		@UserId = @UserId
		,@IsFirstLogin = @IsFirstLogin OUTPUT
	
	BEGIN TRY
		UPDATE	dbo.UserInfo WITH(ROWLOCK, UPDLOCK)
				SET	DisplayName		= @DisplayName
					,CompanyName	= @CompanyName 
					,PositionId		= CASE WHEN ISNULL(PositionId,0) = 0 THEN @PositionId ELSE PositionId END -- cannot change position if user has assigned position already
					,JoinedDate		= @JoinedDate 
					,CountryName	= @CountryName 
					,Email			= @Email 
					,PhoneNumber	= @PhoneNumber 
					,Skype			= @Skype 
					,Line			= @Line 
					,Remark			= @Remark
		WHERE	UserId = @UserId
		
		IF @@rowcount = 0 -- insert user 
		BEGIN
			INSERT INTO dbo.UserInfo (
					UserId
					,DisplayName
					,CompanyName
					,PositionId
					,JoinedDate
					,CountryName
					,Email
					,PhoneNumber
					,Skype
					,Line
					,Remark
			)
			SELECT	@UserId
					,@DisplayName
					,@CompanyName
					,@PositionId
					,@JoinedDate
					,@CountryName
					,@Email
					,@PhoneNumber
					,@Skype
					,@Line
					,@Remark
		END
		
		-- for the first login, if the user select his position as CS 1on1, assign all types of licensee to the user.
		IF @IsFirstLogin = 1 AND @PositionId = 4 -- CSD
		BEGIN
			INSERT INTO dbo.UserLicenseeType (UserId, LicenseeTypeId)
			SELECT	@UserId
					,LicenseeTypeId
			FROM	dbo.LicenseeType lt WITH(NOLOCK)
			WHERE	NOT EXISTS (SELECT	ult.LicenseeTypeId 
								FROM	dbo.UserLicenseeType ult WITH(NOLOCK) 
								WHERE	ult.LicenseeTypeId = lt.LicenseeTypeId 
										AND ult.UserId = @UserId
								)
			
		END

		IF @IsFirstLogin = 1
			UPDATE dbo.UserLicenseeType
			SET Email = @Email
			WHERE UserId = @UserId
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](20000,@Language) --   Fail to update user profile. Please try again.
            
        RETURN
	END CATCH

	DECLARE @PositionName VARCHAR(50)
	SELECT  @PositionName = PositionName FROM dbo.Position WITH(NOLOCK) WHERE PositionId = @PositionId
	
	-- Write log	
	SET @xml = (
				SELECT	@UserId				AS '@uid'
						,@DisplayName		AS '@udn'
						,@CompanyName		AS '@ucomn'
						,@PositionId		AS '@upi'
						,@PositionName		AS '@upn'
						,@JoinedDate		AS '@ujd'
						,@CountryName		AS '@ucoun'
						,@Email				AS '@ue'
						,@PhoneNumber		AS '@up'
						,@Skype				AS '@us'
						,@Line				AS '@ul'
						,@Remark			AS '@ur'
						,@IsFirstLogin		AS '@fl'
				FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData	= CONVERT(NVARCHAR(MAX),@xml)
		,@endRun		= GETDATE()  
		,@duration		= DATEDIFF(millisecond, @startRun, @endRun)   
		,@procName		= OBJECT_NAME(@@procid)

		EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOldData
		,@Duration		= @Duration
	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_UserInfoUpd_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_UserInfoUpd_xtest    Script Date: 11/11/2016 10:29:58 AM ******/

CREATE PROCEDURE [dbo].[OIC_UserInfoUpd_xtest] 
	@UserId			INT
	,@DisplayName	NVARCHAR(50)
	,@CompanyName	NVARCHAR(50)	= NULL
	,@PositionId	TINYINT
	,@JoinedDate	DATETIME
	,@CountryName	NVARCHAR(50)
	,@Email			VARCHAR(50)
	,@PhoneNumber	VARCHAR(50)
	,@Skype			VARCHAR(50)		= NULL
	,@Line			VARCHAR(50)		= NULL
	,@Remark		NVARCHAR(300)	= NULL
	
	,@IP			VARCHAR(50)		= NULL
	,@Language		VARCHAR(10)		= 'E'
	,@ErrCode		INT				= 0		OUTPUT
	,@ErrMsg		VARCHAR(300)	= ''	OUTPUT
AS
/*
	Created by: Kathy
	Date: 20150617
	Task: update user profile [Redmine:#38087]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		- 20160808@Percy: Update Default Email when first login [RedmineID: #61904]
	
	Param's Explanation:
		
		
 */
BEGIN
	SET NOCOUNT ON
				
	DECLARE @startRun			DATETIME
			,@endRun			DATETIME
			,@duration			INT
			,@logSPData			NVARCHAR(MAX)
			,@logSPOldData		NVARCHAR(MAX)
			,@xml				XML
			,@procName			VARCHAR(200)

			,@IsFirstLogin		BIT				= 0
			
	SET @startRun = GETDATE()	
	
	-- get data before update/insert		
	SET @xml = (
				SELECT	@UserId			AS '@uid'
						,DisplayName	AS '@udn'
						,CompanyName	AS '@ucomn'
						,p.PositionId	AS '@upi'
						,p.PositionName	AS '@upn'
						,JoinedDate		AS '@ujd'
						,CountryName	AS '@ucoun'
						,Email			AS '@ue'
						,PhoneNumber	AS '@up'
						,Skype			AS '@us'
						,Line			AS '@ul'
						,Remark			AS '@ur'
						,@IsFirstLogin	AS '@fl'
				FROM	dbo.UserInfo u WITH(NOLOCK)
					INNER JOIN dbo.Position p WITH(NOLOCK) ON u.PositionId = p.PositionId
				WHERE	UserId = @UserId
				FOR XML PATH('r'), TYPE
	)
	
	SELECT @logSPOldData = CONVERT(NVARCHAR(MAX),@xml)
	
	-- checking display name
	IF EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE DisplayName = @DisplayName AND UserId <> @UserId)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](20001,@Language) --   Display name exists.
            
        RETURN
	END
	
	-- checking first login or not
	EXEC dbo.OIC_UserFirstLoginChecking 
		@UserId = @UserId
		,@IsFirstLogin = @IsFirstLogin OUTPUT
	
	BEGIN TRY
		UPDATE	dbo.UserInfo WITH(ROWLOCK, UPDLOCK)
				SET	DisplayName		= @DisplayName
					,CompanyName	= @CompanyName 
					,PositionId		= CASE WHEN ISNULL(PositionId,0) = 0 THEN @PositionId ELSE PositionId END -- cannot change position if user has assigned position already
					,JoinedDate		= @JoinedDate 
					,CountryName	= @CountryName 
					,Email			= @Email 
					,PhoneNumber	= @PhoneNumber 
					,Skype			= @Skype 
					,Line			= @Line 
					,Remark			= @Remark
		WHERE	UserId = @UserId
		
		IF @@rowcount = 0 -- insert user 
		BEGIN
			INSERT INTO dbo.UserInfo (
					UserId
					,DisplayName
					,CompanyName
					,PositionId
					,JoinedDate
					,CountryName
					,Email
					,PhoneNumber
					,Skype
					,Line
					,Remark
			)
			SELECT	@UserId
					,@DisplayName
					,@CompanyName
					,@PositionId
					,@JoinedDate
					,@CountryName
					,@Email
					,@PhoneNumber
					,@Skype
					,@Line
					,@Remark
		END
		
		-- for the first login, if the user select his position as CS 1on1, assign all types of licensee to the user.
		IF @IsFirstLogin = 1 AND @PositionId = 4 -- CSD
		BEGIN
			INSERT INTO dbo.UserLicenseeType (UserId, LicenseeTypeId)
			SELECT	@UserId
					,LicenseeTypeId
			FROM	dbo.LicenseeType lt WITH(NOLOCK)
			WHERE	NOT EXISTS (SELECT	ult.LicenseeTypeId 
								FROM	dbo.UserLicenseeType ult WITH(NOLOCK) 
								WHERE	ult.LicenseeTypeId = lt.LicenseeTypeId 
										AND ult.UserId = @UserId
								)
			
		END

		IF @IsFirstLogin = 1
			UPDATE dbo.UserLicenseeType
			SET Email = @Email
			WHERE UserId = @UserId
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](20000,@Language) --   Fail to update user profile. Please try again.
            
        RETURN
	END CATCH

	DECLARE @PositionName VARCHAR(50)
	SELECT  @PositionName = PositionName FROM dbo.Position WITH(NOLOCK) WHERE PositionId = @PositionId
	
	-- Write log	
	SET @xml = (
				SELECT	@UserId				AS '@uid'
						,@DisplayName		AS '@udn'
						,@CompanyName		AS '@ucomn'
						,@PositionId		AS '@upi'
						,@PositionName		AS '@upn'
						,@JoinedDate		AS '@ujd'
						,@CountryName		AS '@ucoun'
						,@Email				AS '@ue'
						,@PhoneNumber		AS '@up'
						,@Skype				AS '@us'
						,@Line				AS '@ul'
						,@Remark			AS '@ur'
						,@IsFirstLogin		AS '@fl'
				FOR XML PATH('r'), TYPE
		)		
		
	SELECT @logSPData	= CONVERT(NVARCHAR(MAX),@xml)
		,@endRun		= GETDATE()  
		,@duration		= DATEDIFF(millisecond, @startRun, @endRun)   
		,@procName		= OBJECT_NAME(@@procid)

	EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOldData
		,@Duration		= @Duration
	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_UserLicenseeSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_UserLicenseeSel    Script Date: 6/14/2017 10:35:16 PM ******/
/****** Object:  Stored Procedure dbo.OIC_UserLicenseeSel    Script Date: 6/13/2017 9:18:46 AM ******/

CREATE PROCEDURE [dbo].[OIC_UserLicenseeSel]
	@PositionId		TINYINT
	,@LicenseeName	VARCHAR(30)		
AS

/*
	Created by Percy
	Date: 2017-05-30
	DB: DBOIC.bodb_OIC
	Task: Select Display name of user by licensee [RedmineID: #74879]

	Revisions:
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @LicenseeId INT
	
	SELECT  @LicenseeId = LicenseeId
	FROM dbo.Licensee WITH(NOLOCK)
	WHERE LicenseeName = @LicenseeName

	SELECT ui.DisplayName
	FROM dbo.UserLicensee ul WITH(NOLOCK)
		INNER JOIN dbo.UserInfo ui WITH(NOLOCK) ON ul.UserId = ui.UserId
	WHERE ul.LicenseeId = @LicenseeId
		AND ui.PositionId = @PositionId
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_UserLicenseeSel_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_UserLicenseeSel_xtest    Script Date: 6/13/2017 9:18:46 AM ******/

CREATE PROCEDURE [dbo].[OIC_UserLicenseeSel_xtest]
	@PositionId		TINYINT
	,@LicenseeName	VARCHAR(30)		
AS

/*
	Created by Percy
	Date: 2017-05-30
	DB: DBOIC.bodb_OIC
	Task: Select Display name of user by licensee [RedmineID: #74879]

	Revisions:
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @LicenseeId INT
	
	SELECT  @LicenseeId = LicenseeId
	FROM dbo.Licensee WITH(NOLOCK)
	WHERE LicenseeName = @LicenseeName

	SELECT ui.DisplayName
	FROM dbo.UserLicensee ul WITH(NOLOCK)
		INNER JOIN dbo.UserInfo ui WITH(NOLOCK) ON ul.UserId = ui.UserId
	WHERE ul.LicenseeId = @LicenseeId
		AND ui.PositionId = @PositionId
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_UserListByPositionSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_UserListByPositionSel    Script Date: 05/06/2015 11:12:01 AM ******/
/****** Object:  Stored Procedure dbo.OIC_UserListByPositionSel    Script Date: 15/05/2015 10:19:14 AM ******/
CREATE PROCEDURE [dbo].[OIC_UserListByPositionSel] 
	@PositionId		TINYINT
	,@LicenseeType	TINYINT = 0 -- ALL
	,@UserId		INT		
AS
/*
	Created by: Kathy
	Date: 2014-12-24
	Task: Get users by position [Redmine:#27752]
	DB: DBOIC.bodb_OIC
	
	Revisions:
	
	Param's Explanation:
		* @PositionId: user's position: 5 - PM
										6 - AM
	
 */
BEGIN
	SET NOCOUNT ON
	
	SELECT  DISTINCT ui.UserId
			,ui.DisplayName
	FROM	dbo.UserInfo ui WITH(NOLOCK)
		INNER JOIN UserLicenseeType ul WITH(NOLOCK)
			ON ui.UserId = ul.UserId
	WHERE	ui.PositionId = @PositionId
			AND ul.LicenseeTypeId IN (SELECT LicenseeTypeId 
									  FROM	dbo.UserLicenseeType WITH(NOLOCK) 
									  WHERE UserId = @UserId 
											AND (@LicenseeType = 0 OR LicenseeTypeId = @LicenseeType))
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_UserListByTOLPositionSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_UserListByTOLPositionSel    Script Date: 2/7/2017 9:25:02 AM ******/

CREATE PROCEDURE [dbo].[OIC_UserListByTOLPositionSel]
	@UserId					INT,
	@PositionId				TINYINT,
	@SelectedLicenseeType	VARCHAR(50) = 'All'
AS

/*
	Creator: Percy
	Date: 2016-12-20
	DB: DBOIC.bodb_OIC
	Task: Get User List by Type of Licensee and Position

	Revisions:

	Param's Explanation:
		* @SelectedLicenseeType: list of Type of Licensee
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @tblLicenseeType TABLE (LicenseeTypeId TINYINT)

	IF @SelectedLicenseeType <> 'All'
	BEGIN
		INSERT INTO @tblLicenseeType (LicenseeTypeId)
		SELECT ul.LicenseeTypeId
		FROM dbo.UserLicenseeType ul WITH(NOLOCK)
		WHERE ul.UserId = @UserId
			AND EXISTS (SELECT TOP 1 1 FROM dbo.strSplit(@SelectedLicenseeType, ',') s WHERE ul.LicenseeTypeId = CONVERT(TINYINT, s.val))
	END
	
	SELECT  DISTINCT ui.UserId
			,ui.DisplayName
	FROM	dbo.UserInfo ui WITH(NOLOCK)
		INNER JOIN UserLicenseeType ul WITH(NOLOCK)
			ON ui.UserId = ul.UserId
	WHERE	ui.PositionId = @PositionId
			AND (
				@SelectedLicenseeType = 'All'
				OR EXISTS (SELECT TOP 1 1 FROM @tblLicenseeType lt WHERE ul.LicenseeTypeId = lt.LicenseeTypeId)
			)
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_UserPositionList]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_UserPositionList    Script Date: 21/10/2015 12:37:03 PM ******/
CREATE PROCEDURE [dbo].[OIC_UserPositionList] 
	@DisplayName		NVARCHAR(50)	= '%'
	,@SelectedPosition	VARCHAR(100)	= 'All'
	,@SiteId			INT 
AS

/*
	Created by: Kathy
	Date: 20151002
	Task: list user position [Redmine:#44258]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		@PositionId: All - ALL position
		@SiteId: siteid on NAP Home
 */

BEGIN
	SET NOCOUNT ON;
	
	
	SELECT	ci.custid AS UserId
			,CASE WHEN ISNULL(ui.DisplayName,'') = '' THEN ci.username ELSE ui.DisplayName END AS DisplayName
			,p.PositionId
	FROM bodb_NAP.dbo.UserSite u WITH(NOLOCK)
		INNER JOIN bodb02.dbo.custInfo ci WITH(NOLOCK)
			ON	ci.custid = u.UserId
		LEFT JOIN dbo.UserInfo ui WITH(NOLOCK)
			ON ui.UserId = ci.custid
		LEFT JOIN dbo.Position p WITH(NOLOCK)
			ON ui.PositionId = p.PositionId
	WHERE	u.SiteId = @SiteId
			AND CASE WHEN ui.UserId IS NOT NULL THEN ISNULL(ui.DisplayName,'%')
					 ELSE ISNULL(ci.username,'%') 
					 END LIKE ISNULL(@DisplayName,'%') + '%'
			AND (@SelectedPosition = 'All' 
				OR (EXISTS (SELECT val FROM dbo.strSplit(@SelectedPosition,',') WHERE (val = 0 AND p.PositionId IS NULL) OR val = p.PositionId)) 
				)
			
	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_UserPositionUpd]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_UserPositionUpd    Script Date: 11/21/2016 10:54:23 PM ******/
/****** Object:  Stored Procedure dbo.OIC_UserPositionUpd    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_UserPositionUpd]
	@updUserId		INT
	,@PositionId	TINYINT		
	,@UserId		INT
	,@Language		VARCHAR(10)		= 'E'
	,@IP			VARCHAR(50)		= NULL
	,@ErrCode		INT				= 0			OUTPUT
	,@ErrMsg		VARCHAR(300)	= NULL		OUTPUT
AS

/*
	Created by: Kathy
	Date: 20151002
	Task: update user position [Redmine:#44258]
	DB: DBOIC.bodb_OIC
	
	Revisions:

*/

BEGIN
	SET NOCOUNT ON;
		
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPOlddata	NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
		,@isNewUser		BIT = 0
		,@newDisplayName NVARCHAR(50)

	SET @startRun = GETDATE()
	
	-- If the user is AM or PM, check if there is any client assigned to him.
	IF EXISTS (SELECT TOP 1 1 FROM UserLicensee WITH(NOLOCK) WHERE UserId = @updUserId)
	BEGIN
		SELECT @ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30023,@Language) -- Unable to change the user position because one or many assigned exist(s)
		RETURN
	END
	
	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE UserId = @updUserId)
	BEGIN
		SELECT	@newDisplayName = username
		FROM	bodb02.dbo.custInfo WITH(NOLOCK) 
		WHERE	custid = @updUserId 
				AND roleid >= 5

		IF @@ROWCOUNT = 0
		BEGIN
			SELECT @ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30021, @Language) -- User does not exist
			RETURN
		END
		
		SET @isNewUser = 1
		
		IF EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE DisplayName = @newDisplayName)
		BEGIN
			DECLARE @seq INT = 1
			WHILE(1 = 1)
			BEGIN
				IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE DisplayName = @newDisplayName +' (' + CAST(@seq AS VARCHAR(10)) +')') 
				BEGIN
					SET @newDisplayName = @newDisplayName +' (' + CAST(@seq AS VARCHAR(10)) +')' 
					BREAK
				END
				
				SET @seq = @seq + 1
			END
		END
	END	
	
	IF @isNewUser = 0
		SET @xml = (SELECT	UserId			AS '@uid'
							,DisplayName	AS '@udn'
							,ui.PositionId	AS '@upi'
							,p.PositionName	AS '@upn'
					FROM	dbo.UserInfo ui WITH(NOLOCK)
						INNER JOIN dbo.Position p WITH (NOLOCK)
							ON p.PositionId = ui.PositionId
					WHERE	UserId = @updUserId
					FOR XML PATH('r'), TYPE
				)
	ELSE
		SET @xml = (SELECT	@updUserId			AS '@uid'
							,@newDisplayName	AS '@ddn'
							,NULL				AS '@dpi'
							,NULL				AS '@dpn'
					FOR XML PATH('r'), TYPE
				)
				
	SELECT @logSPOlddata = CONVERT(NVARCHAR(MAX), @xml)
	
	BEGIN TRY
		IF @isNewUser = 0
		BEGIN
			UPDATE	dbo.UserInfo WITH(ROWLOCK, UPDLOCK)
				SET	PositionId = @PositionId
			WHERE	UserId = @updUserId
		END
		ELSE 
		BEGIN
			INSERT INTO dbo.UserInfo (UserId, DisplayName, PositionId) VALUES (@updUserId, @newDisplayName, @PositionId)
		END
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 102
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30022, @Language) -- Fail to edit user position. Please try again.
		
		RETURN
	END CATCH
	
	SET @xml = (SELECT	UserId			AS '@uid'
						,DisplayName	AS '@udn'
						,ui.PositionId	AS '@upi'
						,p.PositionName	AS '@upn'
				FROM	dbo.UserInfo ui WITH(NOLOCK)
					INNER JOIN dbo.Position p WITH (NOLOCK)
						ON p.PositionId = ui.PositionId
				WHERE	UserId = @updUserId
				FOR XML PATH('r'), TYPE
				)
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

		EXEC dbo.OIC_LogRunSpIns
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOlddata
		,@Duration		= @Duration	
	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_UserPositionUpd_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_UserPositionUpd_xtest    Script Date: 11/11/2016 10:29:59 AM ******/

CREATE PROCEDURE [dbo].[OIC_UserPositionUpd_xtest]
	@updUserId		INT
	,@PositionId	TINYINT		
	,@UserId		INT
	,@Language		VARCHAR(10)		= 'E'
	,@IP			VARCHAR(50)		= NULL
	,@ErrCode		INT				= 0			OUTPUT
	,@ErrMsg		VARCHAR(300)	= NULL		OUTPUT
AS

/*
	Created by: Kathy
	Date: 20151002
	Task: update user position [Redmine:#44258]
	DB: DBOIC.bodb_OIC
	
	Revisions:

*/

BEGIN
	SET NOCOUNT ON;
		
	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPOlddata	NVARCHAR(MAX)
		,@xml			XML
		,@procName		VARCHAR(200)
		,@isNewUser		BIT = 0
		,@newDisplayName NVARCHAR(50)

	SET @startRun = GETDATE()
	
	-- If the user is AM or PM, check if there is any client assigned to him.
	IF EXISTS (SELECT TOP 1 1 FROM UserLicensee WITH(NOLOCK) WHERE UserId = @updUserId)
	BEGIN
		SELECT @ErrCode = 100
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30023,@Language) -- Unable to change the user position because one or many assigned exist(s)
		RETURN
	END
	
	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE UserId = @updUserId)
	BEGIN
		SELECT	@newDisplayName = username
		FROM	bodb02.dbo.custInfo WITH(NOLOCK) 
		WHERE	custid = @updUserId 
				AND roleid >= 5

		IF @@ROWCOUNT = 0
		BEGIN
			SELECT @ErrCode = 101
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30021, @Language) -- User does not exist
			RETURN
		END
		
		SET @isNewUser = 1
		
		IF EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE DisplayName = @newDisplayName)
		BEGIN
			DECLARE @seq INT = 1
			WHILE(1 = 1)
			BEGIN
				IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.UserInfo WITH(NOLOCK) WHERE DisplayName = @newDisplayName +' (' + CAST(@seq AS VARCHAR(10)) +')') 
				BEGIN
					SET @newDisplayName = @newDisplayName +' (' + CAST(@seq AS VARCHAR(10)) +')' 
					BREAK
				END
				
				SET @seq = @seq + 1
			END
		END
	END	
	
	IF @isNewUser = 0
		SET @xml = (SELECT	UserId			AS '@uid'
							,DisplayName	AS '@udn'
							,ui.PositionId	AS '@upi'
							,p.PositionName	AS '@upn'
					FROM	dbo.UserInfo ui WITH(NOLOCK)
						INNER JOIN dbo.Position p WITH (NOLOCK)
							ON p.PositionId = ui.PositionId
					WHERE	UserId = @updUserId
					FOR XML PATH('r'), TYPE
				)
	ELSE
		SET @xml = (SELECT	@updUserId			AS '@uid'
							,@newDisplayName	AS '@ddn'
							,NULL				AS '@dpi'
							,NULL				AS '@dpn'
					FOR XML PATH('r'), TYPE
				)
				
	SELECT @logSPOlddata = CONVERT(NVARCHAR(MAX), @xml)
	
	BEGIN TRY
		IF @isNewUser = 0
		BEGIN
			UPDATE	dbo.UserInfo WITH(ROWLOCK, UPDLOCK)
				SET	PositionId = @PositionId
			WHERE	UserId = @updUserId
		END
		ELSE 
		BEGIN
			INSERT INTO dbo.UserInfo (UserId, DisplayName, PositionId) VALUES (@updUserId, @newDisplayName, @PositionId)
		END
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 102
				,@ErrMsg = [dbo].[f_Get_MsgNamebyMsgID](30022, @Language) -- Fail to edit user position. Please try again.
		
		RETURN
	END CATCH
	
	SET @xml = (SELECT	UserId			AS '@uid'
						,DisplayName	AS '@udn'
						,ui.PositionId	AS '@upi'
						,p.PositionName	AS '@upn'
				FROM	dbo.UserInfo ui WITH(NOLOCK)
					INNER JOIN dbo.Position p WITH (NOLOCK)
						ON p.PositionId = ui.PositionId
				WHERE	UserId = @updUserId
				FOR XML PATH('r'), TYPE
				)
		
	SELECT @logSPData = CONVERT(NVARCHAR(MAX), @xml)
		,@endRun	= GETDATE()  
		,@duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   
		,@procName	= OBJECT_NAME(@@PROCID)

	EXEC dbo.OIC_LogRunSpIns_xtest
		@UserId			= @UserId
		,@SPName		= @procName
		,@Language		= @Language
		,@IP			= @IP
		,@Data			= @logSPData
		,@OldData		= @logSPOlddata
		,@Duration		= @Duration	
	
END
GO
/****** Object:  StoredProcedure [dbo].[OIC_UserSel]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.OIC_UserSel    Script Date: 26/08/2015 12:33:23 PM ******/
/****** Object:  Stored Procedure dbo.OIC_UserSel    Script Date: 12/08/2015 5:55:46 PM ******/
CREATE PROCEDURE [dbo].[OIC_UserSel] 
AS
/*
	Created by: Kathy
	Date: 20150730
	Task: get all user [Redmine:#40305]
	DB: DBOIC.bodb_OIC
	
	Revisions:
		
	Param's Explanation:
		@Mode = 0: ALL
				1: get all position and user belong to 
				
 */
BEGIN
	SET NOCOUNT ON

	SELECT	UserId
			,DisplayName
	FROM	dbo.UserInfo WITH(NOLOCK)
END
GO
/****** Object:  UserDefinedFunction [dbo].[f_Get_MsgNamebyMsgID]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/****** Object:  User Defined Function dbo.f_Get_MsgNamebyMsgID    Script Date: 09/02/2015 3:30:04 PM ******/
CREATE FUNCTION [dbo].[f_Get_MsgNamebyMsgID]
(
    @MsgID        INT,
    @Language    NVARCHAR(5)='E' 
)
RETURNS NVARCHAR(4000) 
AS
/*
    Created by: Kathy
    Date: 2014-12-18
    Task: Get the content of message from msgID 
    DB: DBOIC/BODB_OIC 
    
    Revisions: 
    
*/
BEGIN
    -- Declare the return variable here
    DECLARE    @MsgName    NVARCHAR(4000)

    SELECT    @MsgName = ContentEn                                        
    FROM    dbo.MessageError WITH (NOLOCK)
    WHERE    MessageErrorId  = @MsgID

    -- Return the result of the function
    RETURN    @MsgName

END



GO
/****** Object:  UserDefinedFunction [dbo].[f_LicenseeBelongToLicenseeType]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  User Defined Function dbo.f_LicenseeBelongToLicenseeType    Script Date: 17/09/2015 3:31:00 PM ******/
/****** Object:  User Defined Function dbo.f_LicenseeBelongToLicenseeType    Script Date: 28/08/2015 4:12:40 PM ******/



/****** Object:  User Defined Function dbo.strSplit    Script Date: 09/02/2015 3:30:04 PM ******/
CREATE FUNCTION [dbo].[f_LicenseeBelongToLicenseeType] (@UserId INT)
RETURNS @res TABLE (
	LicenseeTypeId		TINYINT NOT NULL
	,LicenseeTypeName	NVARCHAR(50) NOT NULL
	,LicenseeId			INT 
	,LicenseeName		NVARCHAR(50) 
	) WITH EXECUTE AS CALLER
AS
BEGIN
	INSERT INTO @res (LicenseeTypeId, LicenseeTypeName, LicenseeId, LicenseeName)
	SELECT  lt.LicenseeTypeId, lt.LicenseeTypeName, f.LicenseeId, f.LicenseeName
	FROM	dbo.LicenseeType lt WITH(NOLOCK)
		LEFT JOIN dbo.f_LicenseeBelongToUser (@UserId) f
			ON lt.LicenseeTypeId = f.LicenseeTypeId
	
	RETURN
END
GO
/****** Object:  UserDefinedFunction [dbo].[f_LicenseeBelongToProduct]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  User Defined Function dbo.f_LicenseeBelongToProduct    Script Date: 3/17/2016 5:02:56 AM ******/
/****** Object:  User Defined Function dbo.f_LicenseeBelongToProduct    Script Date: 17/03/2016 9:28:14 AM ******/
/****** Object:  User Defined Function dbo.f_LicenseeBelongToProduct    Script Date: 17/03/2016 9:25:56 AM ******/
/****** Object:  User Defined Function dbo.f_LicenseeBelongToProduct    Script Date: 3/15/2016 10:50:20 AM ******/


/****** Object:  User Defined Function dbo.strSplit    Script Date: 09/02/2015 3:30:04 PM ******/
CREATE FUNCTION [dbo].[f_LicenseeBelongToProduct] (@ProductId TINYINT, @UserId INT)
RETURNS @res TABLE (
	LicenseeId INT NOT NULL
	,LicenseeName NVARCHAR(50) NOT NULL
	,LicenseeTypeId	INT NOT NULL
	,LicenseeTypeName VARCHAR(30) NOT NULL
	,PRIMARY KEY CLUSTERED (LicenseeId ASC)
	) WITH EXECUTE AS CALLER
AS
BEGIN
	INSERT INTO @res (LicenseeId, LicenseeName, LicenseeTypeId, LicenseeTypeName)
	SELECT  l.LicenseeId, l.LicenseeName, l.LicenseeTypeId, f.LicenseeTypeName
	FROM	dbo.Licensee l WITH(NOLOCK)
		INNER JOIN dbo.LicenseeProduct lp WITH(NOLOCK)
			ON l.LicenseeId = lp.LicenseeId
		INNER JOIN dbo.f_LicenseeTypeBelongToUser(@UserId) f
			ON f.LicenseeTypeId = l.LicenseeTypeId
	WHERE	lp.ProductId = @ProductId
	
	RETURN
END
GO
/****** Object:  UserDefinedFunction [dbo].[f_LicenseeBelongToProduct_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  User Defined Function dbo.f_LicenseeBelongToProduct_xtest    Script Date: 17/03/2016 9:28:14 AM ******/
/****** Object:  User Defined Function dbo.f_LicenseeBelongToProduct_xtest    Script Date: 17/03/2016 9:25:56 AM ******/
/****** Object:  User Defined Function dbo.f_LicenseeBelongToProduct_xtest    Script Date: 3/15/2016 10:50:20 AM ******/


/****** Object:  User Defined Function dbo.strSplit    Script Date: 09/02/2015 3:30:04 PM ******/
CREATE FUNCTION [dbo].[f_LicenseeBelongToProduct_xtest] (@ProductId TINYINT, @UserId INT)
RETURNS @res TABLE (
	LicenseeId INT NOT NULL
	,LicenseeName NVARCHAR(50) NOT NULL
	,LicenseeTypeId	INT NOT NULL
	,LicenseeTypeName VARCHAR(30) NOT NULL
	,PRIMARY KEY CLUSTERED (LicenseeId ASC)
	) WITH EXECUTE AS CALLER
AS
BEGIN
	INSERT INTO @res (LicenseeId, LicenseeName, LicenseeTypeId, LicenseeTypeName)
	SELECT  l.LicenseeId, l.LicenseeName, l.LicenseeTypeId, f.LicenseeTypeName
	FROM	dbo.Licensee l WITH(NOLOCK)
		INNER JOIN dbo.LicenseeProduct lp WITH(NOLOCK)
			ON l.LicenseeId = lp.LicenseeId
		INNER JOIN dbo.f_LicenseeTypeBelongToUser(@UserId) f
			ON f.LicenseeTypeId = l.LicenseeTypeId
	WHERE	lp.ProductId = @ProductId
	
	RETURN
END
GO
/****** Object:  UserDefinedFunction [dbo].[f_LicenseeBelongToUser]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  User Defined Function dbo.f_LicenseeBelongToUser    Script Date: 3/17/2016 5:02:55 AM ******/
/****** Object:  User Defined Function dbo.f_LicenseeBelongToUser    Script Date: 17/03/2016 9:28:14 AM ******/
/****** Object:  User Defined Function dbo.f_LicenseeBelongToUser    Script Date: 17/03/2016 9:25:55 AM ******/
/****** Object:  User Defined Function dbo.f_LicenseeBelongToUser    Script Date: 3/15/2016 10:50:20 AM ******/

/****** Object:  User Defined Function dbo.strSplit    Script Date: 09/02/2015 3:30:04 PM ******/
CREATE FUNCTION [dbo].[f_LicenseeBelongToUser] (@UserId INT)
RETURNS @res TABLE (
	LicenseeId INT NOT NULL
	,LicenseeName NVARCHAR(50) NOT NULL
	,LicenseeTypeId TINYINT NOT NULL
	,LicenseeStatusID TINYINT NOT NULL
	,PRIMARY KEY CLUSTERED (LicenseeId ASC)
	) WITH EXECUTE AS CALLER
AS
BEGIN
	DECLARE @tblLicenseeType TABLE (LicenseeTypeId TINYINT)
	
	INSERT INTO @tblLicenseeType(LicenseeTypeId)
	SELECT  LicenseeTypeId
	FROM	dbo.UserLicenseeType WITH(NOLOCK)
	WHERE	UserId = @UserId
	
	INSERT INTO @res (LicenseeId, LicenseeName, LicenseeTypeId, LicenseeStatusID)
	SELECT  LicenseeId, LicenseeName, LicenseeTypeId, LicenseeStatusId
	FROM	dbo.Licensee WITH(NOLOCK)
	WHERE	LicenseeTypeId IN (SELECT LicenseeTypeId FROM @tblLicenseeType)
	
	RETURN
END
GO
/****** Object:  UserDefinedFunction [dbo].[f_LicenseeBelongToUser_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  User Defined Function dbo.f_LicenseeBelongToUser_xtest    Script Date: 17/03/2016 9:28:14 AM ******/
/****** Object:  User Defined Function dbo.f_LicenseeBelongToUser_xtest    Script Date: 17/03/2016 9:25:55 AM ******/
/****** Object:  User Defined Function dbo.f_LicenseeBelongToUser_xtest    Script Date: 3/15/2016 10:50:20 AM ******/

/****** Object:  User Defined Function dbo.strSplit    Script Date: 09/02/2015 3:30:04 PM ******/
CREATE FUNCTION [dbo].[f_LicenseeBelongToUser_xtest] (@UserId INT)
RETURNS @res TABLE (
	LicenseeId INT NOT NULL
	,LicenseeName NVARCHAR(50) NOT NULL
	,LicenseeTypeId TINYINT NOT NULL
	,LicenseeStatusID TINYINT NOT NULL
	,PRIMARY KEY CLUSTERED (LicenseeId ASC)
	) WITH EXECUTE AS CALLER
AS
BEGIN
	DECLARE @tblLicenseeType TABLE (LicenseeTypeId TINYINT)
	
	INSERT INTO @tblLicenseeType(LicenseeTypeId)
	SELECT  LicenseeTypeId
	FROM	dbo.UserLicenseeType WITH(NOLOCK)
	WHERE	UserId = @UserId
	
	INSERT INTO @res (LicenseeId, LicenseeName, LicenseeTypeId, LicenseeStatusID)
	SELECT  LicenseeId, LicenseeName, LicenseeTypeId, LicenseeStatusId
	FROM	dbo.Licensee WITH(NOLOCK)
	WHERE	LicenseeTypeId IN (SELECT LicenseeTypeId FROM @tblLicenseeType)
	
	RETURN
END
GO
/****** Object:  UserDefinedFunction [dbo].[f_LicenseeTypeBelongToUser]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  User Defined Function dbo.f_LicenseeTypeBelongToUser    Script Date: 17/09/2015 3:31:00 PM ******/
/****** Object:  User Defined Function dbo.f_LicenseeTypeBelongToUser    Script Date: 28/08/2015 4:12:40 PM ******/


/****** Object:  User Defined Function dbo.strSplit    Script Date: 09/02/2015 3:30:04 PM ******/
CREATE FUNCTION [dbo].[f_LicenseeTypeBelongToUser] (@UserId INT)
RETURNS @res TABLE (
	LicenseeTypeId		INT NOT NULL
	,LicenseeTypeName	VARCHAR(30) NOT NULL
	,PRIMARY KEY CLUSTERED (LicenseeTypeId ASC)
	) WITH EXECUTE AS CALLER
AS
BEGIN
	;WITH cteUserLicenseeType
	AS (
		SELECT	LicenseeTypeId
		FROM	dbo.UserLicenseeType WITH(NOLOCK)
		WHERE	UserId = @UserId
	)
	INSERT INTO @res (LicenseeTypeId, LicenseeTypeName)
	SELECT	l.LicenseeTypeId, l.LicenseeTypeName
	FROM	cteUserLicenseeType c
		INNER JOIN dbo.LicenseeType l WITH(NOLOCK)
			ON c.LicenseeTypeId = l.LicenseeTypeId
	
	RETURN
END
GO
/****** Object:  UserDefinedFunction [dbo].[f_PositionNotificationList]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  User Defined Function dbo.f_PositionNotificationList    Script Date: 26/08/2015 12:33:24 PM ******/

/****** Object:  User Defined Function dbo.strSplit    Script Date: 09/02/2015 3:30:04 PM ******/
CREATE FUNCTION [dbo].[f_PositionNotificationList] (@EventId INT)
RETURNS @res TABLE (
	PositionId TINYINT NOT NULL
	,PRIMARY KEY CLUSTERED (PositionId ASC)
	) WITH EXECUTE AS CALLER
AS
BEGIN
	-- User Profile, User Position function
	IF @EventId IN (30,31, 32, 33)
	BEGIN
		INSERT INTO @res (PositionId) VALUES (1), (2), (3), (4)
	END
	RETURN
END
GO
/****** Object:  UserDefinedFunction [dbo].[f_RecipientList]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  User Defined Function dbo.f_RecipientList    Script Date: 8/16/2016 4:32:39 AM ******/
/****** Object:  User Defined Function dbo.f_RecipientList    Script Date: 8/15/2016 5:12:04 PM ******/
CREATE FUNCTION [dbo].[f_RecipientList] (
	@SelectedLicensee	VARCHAR(MAX)
	,@CategoryId		TINYINT
	,@UserId			INT
)
RETURNS @res TABLE (
	LicenseeId			INT NOT NULL
	,Recipient			INT NOT NULL
	,RecipientName		NVARCHAR(50)
	,Email				NVARCHAR(50)
	,IsContact			BIT NOT NULL
	,RecipientType		TINYINT 
	) WITH EXECUTE AS CALLER
AS
BEGIN
	DECLARE @tblLicensee TABLE (LicenseeId INT, LicenseeTypeId TINYINT)
	
	--DECLARE @tblRecipientList TABLE (
	--	LicenseeId		INT
	--	,Recipient		INT
	--	,RecipientName	NVARCHAR(50)
	--	,Email			NVARCHAR(50)
	--	,IsContact		BIT
	--	,RecipientType	TINYINT
	--)
	
	DECLARE @UserEmail		NVARCHAR(50)
			,@DisplayName	NVARCHAR(50)
	
	SELECT @UserEmail = Email
			,@DisplayName = DisplayName
	FROM	dbo.UserInfo WITH(NOLOCK)
	WHERE	UserId = @UserId
	
	INSERT INTO @tblLicensee (LicenseeId, LicenseeTypeId)
	SELECT	DISTINCT LicenseeId, LicenseeTypeId
	FROM	dbo.Licensee WITH(NOLOCK)
	WHERE	LicenseeId IN (SELECT val FROM dbo.strSplit(@SelectedLicensee,','))
	
	INSERT INTO @res(
			LicenseeId
			,Recipient
			,RecipientName
			,Email
			,IsContact
			,RecipientType
		)
	SELECT	c.LicenseeId
			,c.ContactId
			,c.ContactName
			,c.ContactEmail
			,1
			,cc.RecipientType
	FROM	dbo.Contact c WITH(NOLOCK)
		INNER JOIN CategoryContact cc WITH(NOLOCK)
			ON	c.ContactId = cc.ContactId
				AND cc.CategoryId = @CategoryId
	WHERE	c.LicenseeId IN (SELECT LicenseeId FROM @tblLicensee)
	
	--UPDATE r
	--SET		RecipientType = cc.RecipientType
	--FROM	CategoryContact cc WITH(NOLOCK)
	--	INNER JOIN @res r
	--		ON r.Recipient = cc.ContactId
	--WHERE	CategoryId = @CategoryId
	
	INSERT INTO @res (LicenseeId, Recipient, RecipientName, Email, IsContact, RecipientType)
	SELECT	ul.LicenseeId
			,ui.UserId -- AM
			,ui.DisplayName
			,ult.Email
			,0
			,2 -- AddtoCc
	FROM	dbo.UserLicensee ul WITH(NOLOCK)
		INNER JOIN dbo.UserInfo ui WITH(NOLOCK)
			ON ul.UserId = ui.UserId
		INNER JOIN dbo.UserLicenseeType ult WITH(NOLOCK)
			ON ui.UserId = ult.UserId
		INNER JOIN @tblLicensee t 
			ON t.LicenseeId = ul.LicenseeId AND t.LicenseeTypeId = ult.LicenseeTypeId
	WHERE	ui.PositionId = 6
	UNION 
	SELECT	t.LicenseeId
			,ui.UserId -- HOD AM
			,ui.DisplayName
			,ult.Email
			,0
			,2 -- AddtoCc
	FROM	dbo.UserInfo ui WITH(NOLOCK)
		INNER JOIN dbo.UserLicenseeType ult WITH(NOLOCK)
			ON ui.UserId = ult.UserId
		INNER JOIN @tblLicensee t 
			ON t.LicenseeTypeId = ult.LicenseeTypeId
	WHERE	ui.PositionId = 3 
	UNION
	SELECT	LicenseeId
			,0 -- system
			,'system'
			,CcList
			,0
			,2 -- AddtoCc
	FROM	@tblLicensee
		CROSS APPLY dbo.EmailConfiguration 
	UNION
	SELECT	LicenseeId
			,0 -- system
			,'system'
			,BccList
			,0
			,3 -- bcc			
	FROM	@tblLicensee
		CROSS APPLY dbo.EmailConfiguration 
	
	
	RETURN
END
GO
/****** Object:  UserDefinedFunction [dbo].[f_RecipientList_xtest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  User Defined Function dbo.f_RecipientList_xtest    Script Date: 8/15/2016 5:12:04 PM ******/
CREATE FUNCTION [dbo].[f_RecipientList_xtest] (
	@SelectedLicensee	VARCHAR(MAX)
	,@CategoryId		TINYINT
	,@UserId			INT
)
RETURNS @res TABLE (
	LicenseeId			INT NOT NULL
	,Recipient			INT NOT NULL
	,RecipientName		NVARCHAR(50)
	,Email				NVARCHAR(50)
	,IsContact			BIT NOT NULL
	,RecipientType		TINYINT 
	) WITH EXECUTE AS CALLER
AS
BEGIN
	DECLARE @tblLicensee TABLE (LicenseeId INT, LicenseeTypeId TINYINT)
	
	--DECLARE @tblRecipientList TABLE (
	--	LicenseeId		INT
	--	,Recipient		INT
	--	,RecipientName	NVARCHAR(50)
	--	,Email			NVARCHAR(50)
	--	,IsContact		BIT
	--	,RecipientType	TINYINT
	--)
	
	DECLARE @UserEmail		NVARCHAR(50)
			,@DisplayName	NVARCHAR(50)
	
	SELECT @UserEmail = Email
			,@DisplayName = DisplayName
	FROM	dbo.UserInfo WITH(NOLOCK)
	WHERE	UserId = @UserId
	
	INSERT INTO @tblLicensee (LicenseeId, LicenseeTypeId)
	SELECT	DISTINCT LicenseeId, LicenseeTypeId
	FROM	dbo.Licensee WITH(NOLOCK)
	WHERE	LicenseeId IN (SELECT val FROM dbo.strSplit(@SelectedLicensee,','))
	
	INSERT INTO @res(
			LicenseeId
			,Recipient
			,RecipientName
			,Email
			,IsContact
			,RecipientType
		)
	SELECT	c.LicenseeId
			,c.ContactId
			,c.ContactName
			,c.ContactEmail
			,1
			,cc.RecipientType
	FROM	dbo.Contact c WITH(NOLOCK)
		INNER JOIN CategoryContact cc WITH(NOLOCK)
			ON	c.ContactId = cc.ContactId
				AND cc.CategoryId = @CategoryId
	WHERE	c.LicenseeId IN (SELECT LicenseeId FROM @tblLicensee)
	
	--UPDATE r
	--SET		RecipientType = cc.RecipientType
	--FROM	CategoryContact cc WITH(NOLOCK)
	--	INNER JOIN @res r
	--		ON r.Recipient = cc.ContactId
	--WHERE	CategoryId = @CategoryId
	
	INSERT INTO @res (LicenseeId, Recipient, RecipientName, Email, IsContact, RecipientType)
	SELECT	ul.LicenseeId
			,ui.UserId -- AM
			,ui.DisplayName
			,ult.Email
			,0
			,2 -- AddtoCc
	FROM	dbo.UserLicensee ul WITH(NOLOCK)
		INNER JOIN dbo.UserInfo ui WITH(NOLOCK)
			ON ul.UserId = ui.UserId
		INNER JOIN dbo.UserLicenseeType ult WITH(NOLOCK)
			ON ui.UserId = ult.UserId
		INNER JOIN @tblLicensee t 
			ON t.LicenseeId = ul.LicenseeId AND t.LicenseeTypeId = ult.LicenseeTypeId
	WHERE	ui.PositionId = 6
	UNION 
	SELECT	t.LicenseeId
			,ui.UserId -- HOD AM
			,ui.DisplayName
			,ult.Email
			,0
			,2 -- AddtoCc
	FROM	dbo.UserInfo ui WITH(NOLOCK)
		INNER JOIN dbo.UserLicenseeType ult WITH(NOLOCK)
			ON ui.UserId = ult.UserId
		INNER JOIN @tblLicensee t 
			ON t.LicenseeTypeId = ult.LicenseeTypeId
	WHERE	ui.PositionId = 3 
	UNION
	SELECT	LicenseeId
			,0 -- system
			,'system'
			,CcList
			,0
			,2 -- AddtoCc
	FROM	@tblLicensee
		CROSS APPLY dbo.EmailConfiguration 
	UNION
	SELECT	LicenseeId
			,0 -- system
			,'system'
			,BccList
			,0
			,3 -- bcc			
	FROM	@tblLicensee
		CROSS APPLY dbo.EmailConfiguration 
	
	
	RETURN
END
GO
/****** Object:  UserDefinedFunction [dbo].[strSplit]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/****** Object:  User Defined Function dbo.strSplit    Script Date: 09/02/2015 3:30:04 PM ******/
CREATE FUNCTION [dbo].[strSplit] (
    @string        NVARCHAR(MAX)
    ,@splitter    CHAR(1)
    )
RETURNS @res TABLE (
    [id]        INT NOT NULL
    ,[rank]        INT NULL
    ,[val]        NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    ,PRIMARY KEY CLUSTERED ([id] ASC)
    ) WITH EXECUTE AS CALLER
AS
BEGIN
    IF SUBSTRING(@string, LEN(@string), 1) <> @splitter
        SET @string = @string + @splitter

    DECLARE @start INT
        ,@word NVARCHAR(MAX)
        ,@charindex INT
        ,@i INT

    SET @i = 1
    SET @start = 1
    SET @charindex = CHARINDEX(@splitter, @string, @start)

    WHILE (@charindex <> 0)
    BEGIN
        SET @word = SUBSTRING(@string, @start, @charindex - @start)
        SET @start = @charindex + 1
        SET @charindex = CHARINDEX(@splitter, @string, @start)

        INSERT INTO @res
        VALUES (
            @start
            ,@i
            ,@word
            )

        SET @i = @i + 1
    END

    RETURN
END


GO
/****** Object:  Table [dbo].[AmendmentMessage]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AmendmentMessage](
	[MessageID] [int] IDENTITY(1,1) NOT NULL,
	[ContentEn] [nvarchar](max) NULL,
	[ContentCh] [nvarchar](max) NULL,
	[ContentCs] [nvarchar](max) NULL,
	[SubjectEn] [nvarchar](300) NOT NULL,
	[SubjectCh] [nvarchar](300) NULL,
	[SubjectCs] [nvarchar](300) NULL,
	[Status] [smallint] NOT NULL,
	[ReceivedDate] [datetime] NOT NULL,
	[UpdatedDate] [datetime] NULL,
	[UpdatedBy] [int] NULL,
	[IsTest] [bit] NOT NULL,
	[EventDate] [datetime] NOT NULL,
	[PublishedDate] [datetime] NULL,
 CONSTRAINT [PK_AmendmentMessage] PRIMARY KEY CLUSTERED 
(
	[MessageID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Message]
) ON [bodb_OIC_Message] TEXTIMAGE_ON [bodb_OIC_Message]

GO
/****** Object:  Table [dbo].[AmendmentMessage_20180118_bk]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AmendmentMessage_20180118_bk](
	[MessageID] [int] IDENTITY(1,1) NOT NULL,
	[ContentEn] [nvarchar](max) NULL,
	[ContentCh] [nvarchar](max) NULL,
	[ContentCs] [nvarchar](max) NULL,
	[SubjectEn] [nvarchar](300) NOT NULL,
	[SubjectCh] [nvarchar](300) NULL,
	[SubjectCs] [nvarchar](300) NULL,
	[Status] [smallint] NOT NULL,
	[ReceivedDate] [datetime] NOT NULL,
	[UpdatedDate] [datetime] NULL,
	[UpdatedBy] [int] NULL,
	[IsTest] [bit] NOT NULL,
	[EventDate] [datetime] NOT NULL
) ON [bodb_OIC_Data] TEXTIMAGE_ON [bodb_OIC_Data]

GO
/****** Object:  Table [dbo].[AmendmentMessage_20180126_bk]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AmendmentMessage_20180126_bk](
	[MessageID] [int] IDENTITY(1,1) NOT NULL,
	[ContentEn] [nvarchar](max) NULL,
	[ContentCh] [nvarchar](max) NULL,
	[ContentCs] [nvarchar](max) NULL,
	[SubjectEn] [nvarchar](300) NOT NULL,
	[SubjectCh] [nvarchar](300) NULL,
	[SubjectCs] [nvarchar](300) NULL,
	[Status] [smallint] NOT NULL,
	[ReceivedDate] [datetime] NOT NULL,
	[UpdatedDate] [datetime] NULL,
	[UpdatedBy] [int] NULL,
	[IsTest] [bit] NOT NULL,
	[EventDate] [datetime] NOT NULL
) ON [bodb_OIC_Data] TEXTIMAGE_ON [bodb_OIC_Data]

GO
/****** Object:  Table [dbo].[AmendmentMessage_20180523_bk]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AmendmentMessage_20180523_bk](
	[MessageID] [int] IDENTITY(1,1) NOT NULL,
	[ContentEn] [nvarchar](max) NULL,
	[ContentCh] [nvarchar](max) NULL,
	[ContentCs] [nvarchar](max) NULL,
	[SubjectEn] [nvarchar](300) NOT NULL,
	[SubjectCh] [nvarchar](300) NULL,
	[SubjectCs] [nvarchar](300) NULL,
	[Status] [smallint] NOT NULL,
	[ReceivedDate] [datetime] NOT NULL,
	[UpdatedDate] [datetime] NULL,
	[UpdatedBy] [int] NULL,
	[IsTest] [bit] NOT NULL,
	[EventDate] [datetime] NOT NULL
) ON [bodb_OIC_Data] TEXTIMAGE_ON [bodb_OIC_Data]

GO
/****** Object:  Table [dbo].[AmendmentMessage_20180525_bk]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AmendmentMessage_20180525_bk](
	[MessageID] [int] IDENTITY(1,1) NOT NULL,
	[ContentEn] [nvarchar](max) NULL,
	[ContentCh] [nvarchar](max) NULL,
	[ContentCs] [nvarchar](max) NULL,
	[SubjectEn] [nvarchar](300) NOT NULL,
	[SubjectCh] [nvarchar](300) NULL,
	[SubjectCs] [nvarchar](300) NULL,
	[Status] [smallint] NOT NULL,
	[ReceivedDate] [datetime] NOT NULL,
	[UpdatedDate] [datetime] NULL,
	[UpdatedBy] [int] NULL,
	[IsTest] [bit] NOT NULL,
	[EventDate] [datetime] NOT NULL,
	[PublishedDate] [datetime] NULL
) ON [bodb_OIC_Data] TEXTIMAGE_ON [bodb_OIC_Data]

GO
/****** Object:  Table [dbo].[AmendmentTicket]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AmendmentTicket](
	[TicketID] [int] IDENTITY(1,1) NOT NULL,
	[LicenseeName] [nvarchar](50) NOT NULL,
	[DataFilePath] [nvarchar](300) NOT NULL,
	[MessageID] [int] NOT NULL,
 CONSTRAINT [PK_AmendmentTicket] PRIMARY KEY CLUSTERED 
(
	[TicketID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
/****** Object:  Table [dbo].[AmendmentTicket_20180118_bk]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AmendmentTicket_20180118_bk](
	[TicketID] [int] IDENTITY(1,1) NOT NULL,
	[LicenseeName] [nvarchar](50) NOT NULL,
	[DataFilePath] [nvarchar](300) NOT NULL,
	[MessageID] [int] NOT NULL
) ON [bodb_OIC_Data]

GO
/****** Object:  Table [dbo].[AmendmentTicket_20180126_bk]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AmendmentTicket_20180126_bk](
	[TicketID] [int] IDENTITY(1,1) NOT NULL,
	[LicenseeName] [nvarchar](50) NOT NULL,
	[DataFilePath] [nvarchar](300) NOT NULL,
	[MessageID] [int] NOT NULL
) ON [bodb_OIC_Data]

GO
/****** Object:  Table [dbo].[Category]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Category](
	[CategoryId] [tinyint] IDENTITY(1,1) NOT NULL,
	[CategoryName] [varchar](100) NULL,
	[CategoryNameCN] [nvarchar](100) NULL,
 CONSTRAINT [Pk_Category] PRIMARY KEY CLUSTERED 
(
	[CategoryId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[CategoryContact]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CategoryContact](
	[ContactId] [int] NOT NULL,
	[CategoryId] [tinyint] NOT NULL,
	[RecipientType] [tinyint] NULL,
 CONSTRAINT [PK_CategoryContact] PRIMARY KEY CLUSTERED 
(
	[ContactId] ASC,
	[CategoryId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
/****** Object:  Table [dbo].[CategoryContact_#20170512]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CategoryContact_#20170512](
	[ContactId] [int] NOT NULL,
	[CategoryId] [tinyint] NOT NULL,
	[RecipientType] [tinyint] NULL
) ON [bodb_OIC_Data]

GO
/****** Object:  Table [dbo].[Contact]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Contact](
	[ContactId] [int] IDENTITY(1,1) NOT NULL,
	[LicenseeId] [int] NOT NULL,
	[ContactName] [nvarchar](50) NULL,
	[ContactPosition] [nvarchar](50) NULL,
	[ContactDepartment] [nvarchar](50) NULL,
	[ContactEmail] [varchar](50) NULL,
	[ContactSkype] [varchar](50) NULL,
	[ContactPhoneNumber] [varchar](50) NULL,
	[ContactLandline] [varchar](50) NULL,
	[ContactType] [tinyint] NULL,
	[Remark] [nvarchar](300) NULL,
	[IsMain] [bit] NOT NULL,
 CONSTRAINT [PK_Contact] PRIMARY KEY CLUSTERED 
(
	[ContactId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Contact_#20170512]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Contact_#20170512](
	[ContactId] [int] IDENTITY(1,1) NOT NULL,
	[LicenseeId] [int] NOT NULL,
	[ContactName] [nvarchar](50) NULL,
	[ContactPosition] [nvarchar](50) NULL,
	[ContactDepartment] [nvarchar](50) NULL,
	[ContactEmail] [varchar](50) NULL,
	[ContactSkype] [varchar](50) NULL,
	[ContactPhoneNumber] [varchar](50) NULL,
	[ContactLandline] [varchar](50) NULL,
	[ContactType] [tinyint] NULL,
	[Remark] [nvarchar](300) NULL,
	[IsMain] [bit] NOT NULL
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Department]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Department](
	[DepartmentId] [tinyint] NOT NULL,
	[DepartmentName] [varchar](50) NOT NULL,
 CONSTRAINT [PK_Department] PRIMARY KEY CLUSTERED 
(
	[DepartmentId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[EmailConfiguration]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[EmailConfiguration](
	[CcList] [varchar](300) NULL,
	[BccList] [varchar](300) NULL
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[ExternalMessageUser]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ExternalMessageUser](
	[MessageID] [int] NOT NULL,
	[MessageType] [int] NOT NULL,
	[UserName] [nvarchar](50) NOT NULL,
	[LicenseeName] [nvarchar](50) NOT NULL,
	[IsRead] [bit] NOT NULL,
	[UpdatedDate] [datetime] NOT NULL,
 CONSTRAINT [PK_ExternalMessageUser] PRIMARY KEY CLUSTERED 
(
	[MessageID] ASC,
	[MessageType] ASC,
	[UserName] ASC,
	[LicenseeName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Message]
) ON [bodb_OIC_Message]

GO
/****** Object:  Table [dbo].[Feature]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Feature](
	[FeatureId] [tinyint] IDENTITY(1,1) NOT NULL,
	[FeatureName] [varchar](300) NULL,
 CONSTRAINT [PK_Feature] PRIMARY KEY CLUSTERED 
(
	[FeatureId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Language]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Language](
	[LanguageId] [tinyint] IDENTITY(1,1) NOT NULL,
	[LanguageName] [varchar](50) NULL,
 CONSTRAINT [PK_Language] PRIMARY KEY CLUSTERED 
(
	[LanguageId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Licensee]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Licensee](
	[LicenseeId] [int] IDENTITY(1,1) NOT NULL,
	[LicenseeName] [nvarchar](50) NULL,
	[LicenseeCompanyName] [nvarchar](50) NULL,
	[LicenseeStatusId] [tinyint] NULL,
	[SoftLaunch] [datetime] NULL,
	[FullLaunch] [datetime] NULL,
	[MainUrl] [varchar](3000) NULL,
	[APILinkageUrl] [varchar](3000) NULL,
	[LicenseeLocationId] [int] NULL,
	[RestrictedLocationRemark] [nvarchar](2000) NULL,
	[Remark] [nvarchar](300) NULL,
	[LicenseeTypeId] [tinyint] NULL,
	[IsChineseMarketOnly] [bit] NULL,
	[InternalURL] [varchar](3000) NULL,
	[IsReseller] [bit] NULL,
 CONSTRAINT [PK_Licensee] PRIMARY KEY CLUSTERED 
(
	[LicenseeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[LicenseeAccountInfo]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[LicenseeAccountInfo](
	[AccountId] [int] IDENTITY(1,1) NOT NULL,
	[LicenseeId] [int] NOT NULL,
	[UserName] [nvarchar](50) NULL,
	[UserPwd] [nvarchar](50) NULL,
	[AccountType] [tinyint] NOT NULL,
	[Order] [tinyint] NULL,
	[Url] [varchar](3000) NULL,
 CONSTRAINT [PK_LicenseeAccountInfo] PRIMARY KEY CLUSTERED 
(
	[AccountId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[LicenseeCategoryAssigned]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[LicenseeCategoryAssigned](
	[LicenseeId] [int] NOT NULL,
	[CategoryId] [tinyint] NOT NULL,
 CONSTRAINT [PK_LicenseeCategory] PRIMARY KEY CLUSTERED 
(
	[LicenseeId] ASC,
	[CategoryId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
/****** Object:  Table [dbo].[LicenseeCurrency]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[LicenseeCurrency](
	[LicenseeId] [int] NOT NULL,
	[CurrencyId] [int] NOT NULL,
 CONSTRAINT [PK_LicenseeCurrency] PRIMARY KEY CLUSTERED 
(
	[LicenseeId] ASC,
	[CurrencyId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
/****** Object:  Table [dbo].[LicenseeFeature]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[LicenseeFeature](
	[LicenseeId] [int] NOT NULL,
	[FeatureId] [tinyint] NOT NULL,
	[LaunchDate] [datetime] NULL,
	[TerminationDate] [datetime] NULL,
 CONSTRAINT [PK_LicenseeFeature] PRIMARY KEY CLUSTERED 
(
	[LicenseeId] ASC,
	[FeatureId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
/****** Object:  Table [dbo].[LicenseeLanguage]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[LicenseeLanguage](
	[LicenseeId] [int] NOT NULL,
	[LanguageId] [tinyint] NOT NULL,
	[Remark] [varchar](50) NULL,
 CONSTRAINT [PK_LicenseeLanguage] PRIMARY KEY CLUSTERED 
(
	[LicenseeId] ASC,
	[LanguageId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[LicenseeLocationLimit]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[LicenseeLocationLimit](
	[LicenseeId] [int] NOT NULL,
	[LocationLimitId] [int] NOT NULL,
	[LicenseeLocationType] [tinyint] NOT NULL,
 CONSTRAINT [PK_LicenseeLocation] PRIMARY KEY CLUSTERED 
(
	[LicenseeId] ASC,
	[LocationLimitId] ASC,
	[LicenseeLocationType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
/****** Object:  Table [dbo].[LicenseeMessage]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[LicenseeMessage](
	[LicenseeId] [int] NOT NULL,
	[MessageId] [int] NOT NULL,
 CONSTRAINT [PK_LicenseeMessage] PRIMARY KEY CLUSTERED 
(
	[LicenseeId] ASC,
	[MessageId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Message]
) ON [bodb_OIC_Message]

GO
/****** Object:  Table [dbo].[LicenseeProduct]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[LicenseeProduct](
	[LicenseeId] [int] NOT NULL,
	[ProductId] [tinyint] NOT NULL,
	[LaunchDate] [datetime] NULL,
	[TerminationDate] [datetime] NULL,
 CONSTRAINT [PK_LicenseeProduct] PRIMARY KEY CLUSTERED 
(
	[LicenseeId] ASC,
	[ProductId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
/****** Object:  Table [dbo].[LicenseeProductLanguage]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[LicenseeProductLanguage](
	[LicenseeId] [int] NOT NULL,
	[LanguageId] [tinyint] NOT NULL,
 CONSTRAINT [PK_LicenseeProductLanguage] PRIMARY KEY CLUSTERED 
(
	[LicenseeId] ASC,
	[LanguageId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
/****** Object:  Table [dbo].[LicenseeProperty]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[LicenseeProperty](
	[LicenseeId] [int] NOT NULL,
	[PropertyId] [tinyint] NOT NULL,
	[PropertyValue] [nvarchar](3000) NULL,
 CONSTRAINT [PK_LicenseeProperty] PRIMARY KEY CLUSTERED 
(
	[LicenseeId] ASC,
	[PropertyId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
/****** Object:  Table [dbo].[LicenseeStatus]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[LicenseeStatus](
	[LicenseeStatusId] [tinyint] IDENTITY(1,1) NOT NULL,
	[LicenseeStatusName] [varchar](30) NULL,
 CONSTRAINT [PK_LicenseeStatus] PRIMARY KEY CLUSTERED 
(
	[LicenseeStatusId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[LicenseeType]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[LicenseeType](
	[LicenseeTypeId] [tinyint] IDENTITY(1,1) NOT NULL,
	[LicenseeTypeName] [varchar](30) NULL,
 CONSTRAINT [PK_LicenseeType] PRIMARY KEY CLUSTERED 
(
	[LicenseeTypeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Location]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Location](
	[LocationId] [int] IDENTITY(1,1) NOT NULL,
	[LocationName] [varchar](50) NULL,
 CONSTRAINT [PK_Location] PRIMARY KEY CLUSTERED 
(
	[LocationId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[LogAction]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[LogAction](
	[LogActionId] [int] NOT NULL,
	[LogActionTypeId] [tinyint] NOT NULL,
	[SPName] [varchar](50) NOT NULL,
	[ActionNameEn] [varchar](50) NOT NULL,
	[Item] [varchar](1000) NULL,
	[SubItem] [varchar](1000) NULL,
	[Enable] [bit] NULL,
	[Order] [int] NULL,
 CONSTRAINT [PK_LogAction] PRIMARY KEY CLUSTERED 
(
	[LogActionId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[LogActionType]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[LogActionType](
	[LogActionTypeId] [tinyint] IDENTITY(1,1) NOT NULL,
	[ActionTypeNameEn] [varchar](50) NOT NULL,
 CONSTRAINT [PK_LogActionType] PRIMARY KEY CLUSTERED 
(
	[LogActionTypeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Message]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Message](
	[MessageId] [int] IDENTITY(1,1) NOT NULL,
	[ContentEn] [nvarchar](max) NULL,
	[ContentCh] [nvarchar](max) NULL,
	[ContentCs] [nvarchar](max) NULL,
	[MessageTypeId] [tinyint] NULL,
	[Creator] [int] NOT NULL,
	[CreateTime] [datetime] NULL,
	[SubjectEn] [nvarchar](300) NULL,
	[SubjectCh] [nvarchar](300) NULL,
	[SubjectCs] [nvarchar](300) NULL,
	[ReminderTypeId] [tinyint] NULL,
	[ReminderTypeValue] [xml] NULL,
 CONSTRAINT [PK_Message] PRIMARY KEY CLUSTERED 
(
	[MessageId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Message]
) ON [bodb_OIC_Message] TEXTIMAGE_ON [bodb_OIC_Message]

GO
/****** Object:  Table [dbo].[MessageError]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[MessageError](
	[MessageErrorId] [int] NOT NULL,
	[MessageErrorGroupId] [tinyint] NOT NULL,
	[ContentEn] [varchar](300) NULL,
 CONSTRAINT [PK_MessageError] PRIMARY KEY CLUSTERED 
(
	[MessageErrorId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[MessageErrorGroup]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[MessageErrorGroup](
	[MessageErrorGroupId] [tinyint] IDENTITY(1,1) NOT NULL,
	[GroupName] [varchar](50) NULL,
 CONSTRAINT [PK_MessageErrorGroup] PRIMARY KEY CLUSTERED 
(
	[MessageErrorGroupId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[MessageTarget]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MessageTarget](
	[LicenseeTypeId] [tinyint] NULL,
	[MessageId] [int] NOT NULL,
	[PositionId] [tinyint] NULL
) ON [bodb_OIC_Data]

GO
/****** Object:  Table [dbo].[MessageType]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[MessageType](
	[MessageTypeId] [tinyint] NOT NULL,
	[MessageTypeName] [varchar](50) NOT NULL,
	[Order] [smallint] NULL,
 CONSTRAINT [PK_MessageType] PRIMARY KEY CLUSTERED 
(
	[MessageTypeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Position]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Position](
	[PositionId] [tinyint] NOT NULL,
	[PositionName] [varchar](50) NULL,
	[DepartmentId] [tinyint] NULL,
 CONSTRAINT [PK_Position] PRIMARY KEY CLUSTERED 
(
	[PositionId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Product]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Product](
	[ProductId] [tinyint] IDENTITY(1,1) NOT NULL,
	[ProductName] [varchar](50) NULL,
	[Order] [smallint] NULL,
 CONSTRAINT [PK_Product] PRIMARY KEY CLUSTERED 
(
	[ProductId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Property]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Property](
	[PropertyId] [tinyint] IDENTITY(1,1) NOT NULL,
	[ServiceId] [tinyint] NOT NULL,
	[PropertyName] [varchar](50) NOT NULL,
	[DefaultValue] [varchar](50) NULL,
	[PropertyType] [varchar](30) NOT NULL,
	[Order] [int] NOT NULL,
	[MaxLength] [int] NULL,
 CONSTRAINT [PK_Property] PRIMARY KEY CLUSTERED 
(
	[PropertyId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[ReminderType]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[ReminderType](
	[ReminderTypeId] [tinyint] NOT NULL,
	[ReminderTypeName] [varchar](100) NOT NULL,
 CONSTRAINT [PK_ReminderType] PRIMARY KEY CLUSTERED 
(
	[ReminderTypeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Service]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Service](
	[ServiceId] [tinyint] IDENTITY(1,1) NOT NULL,
	[ServiceName] [varchar](50) NULL,
	[ServiceHint] [varchar](200) NULL,
 CONSTRAINT [PK_Service] PRIMARY KEY CLUSTERED 
(
	[ServiceId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[TrainingAttendee]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TrainingAttendee](
	[AttendeeId] [int] IDENTITY(1,1) NOT NULL,
	[TrainingRequestId] [int] NOT NULL,
	[AttendeeName] [nvarchar](50) NULL,
	[AttendeePosition] [nvarchar](50) NULL,
	[AttendeeSkype] [nvarchar](50) NULL,
 CONSTRAINT [PK_TrainingAttendee] PRIMARY KEY CLUSTERED 
(
	[AttendeeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
/****** Object:  Table [dbo].[TrainingRequest]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[TrainingRequest](
	[TrainingRequestId] [int] IDENTITY(1,1) NOT NULL,
	[LicenseeId] [int] NOT NULL,
	[LanguageUsed] [varchar](30) NULL,
	[TrainingDateUtc] [datetime] NULL,
	[TimeZone] [int] NULL,
	[TrainingStatusId] [tinyint] NULL,
 CONSTRAINT [PK_TrainingRequest] PRIMARY KEY CLUSTERED 
(
	[TrainingRequestId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[TrainingStatus]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[TrainingStatus](
	[TrainingStatusId] [tinyint] NOT NULL,
	[TrainingStatusName] [varchar](200) NULL,
 CONSTRAINT [PK_TrainingStatus] PRIMARY KEY CLUSTERED 
(
	[TrainingStatusId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[TrainingStatusDetail]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[TrainingStatusDetail](
	[TrainingRequestId] [int] NOT NULL,
	[TrainingStatusId] [tinyint] NOT NULL,
	[TrainingStatusValue] [varchar](50) NULL,
 CONSTRAINT [PK_TrainingStatusDetail] PRIMARY KEY CLUSTERED 
(
	[TrainingRequestId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[UrlBackup]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[UrlBackup](
	[UrlId] [int] IDENTITY(1,1) NOT NULL,
	[LicenseeId] [int] NOT NULL,
	[UrlValue] [varchar](3000) NULL,
	[Order] [tinyint] NULL,
 CONSTRAINT [PK_UrlBackup] PRIMARY KEY NONCLUSTERED 
(
	[UrlId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[UserInfo]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[UserInfo](
	[UserId] [int] NOT NULL,
	[DisplayName] [nvarchar](50) NOT NULL,
	[CompanyName] [nvarchar](50) NULL,
	[PositionId] [tinyint] NULL,
	[JoinedDate] [datetime] NULL,
	[CountryName] [nvarchar](50) NULL,
	[Email] [varchar](50) NULL,
	[PhoneNumber] [varchar](50) NULL,
	[Skype] [varchar](50) NULL,
	[Line] [varchar](50) NULL,
	[Remark] [nvarchar](300) NULL,
	[CreateTime] [datetime] NOT NULL,
 CONSTRAINT [PK_UserInfo] PRIMARY KEY CLUSTERED 
(
	[UserId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[UserLicensee]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[UserLicensee](
	[UserId] [int] NOT NULL,
	[LicenseeId] [int] NOT NULL,
 CONSTRAINT [PK_UserLicensee] PRIMARY KEY CLUSTERED 
(
	[UserId] ASC,
	[LicenseeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
/****** Object:  Table [dbo].[UserLicenseeType]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[UserLicenseeType](
	[UserId] [int] NOT NULL,
	[LicenseeTypeId] [tinyint] NOT NULL,
	[Email] [varchar](50) NULL,
 CONSTRAINT [PK_UserLicenseeType] PRIMARY KEY CLUSTERED 
(
	[UserId] ASC,
	[LicenseeTypeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[UserLicenseeType_20180607_bk]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[UserLicenseeType_20180607_bk](
	[UserId] [int] NOT NULL,
	[LicenseeTypeId] [tinyint] NOT NULL,
	[Email] [varchar](50) NULL
) ON [bodb_OIC_Data]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[UserLog_RunSP]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[UserLog_RunSP](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[UserId] [int] NULL,
	[LogActionId] [int] NULL,
	[IP] [varchar](50) NULL,
	[LogDate] [datetime] NULL,
	[Duration] [int] NULL,
 CONSTRAINT [PK_UserLog_RunSP] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_UserLog]
) ON [bodb_OIC_UserLog]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[UserLog_RunSP_Detail]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[UserLog_RunSP_Detail](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[LogActionId] [int] NULL,
	[Data] [nvarchar](max) NULL,
	[OldData] [nvarchar](max) NULL,
 CONSTRAINT [PK_UserLog_RunSP_Detail] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_UserLog]
) ON [bodb_OIC_UserLog] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[UserMessage]    Script Date: 7/20/2018 3:57:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[UserMessage](
	[MessageId] [int] NOT NULL,
	[UserId] [int] NOT NULL,
	[IsRead] [bit] NULL,
	[LastReadTime] [datetime] NULL,
 CONSTRAINT [PK_UserMessage] PRIMARY KEY CLUSTERED 
(
	[UserId] ASC,
	[MessageId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Message]
) ON [bodb_OIC_Message]

GO
ALTER TABLE [dbo].[Contact] ADD  CONSTRAINT [DF_Contact_ContactType]  DEFAULT ((0)) FOR [ContactType]
GO
ALTER TABLE [dbo].[Contact] ADD  CONSTRAINT [DF_Contact_IsMain]  DEFAULT ((0)) FOR [IsMain]
GO
ALTER TABLE [dbo].[Licensee] ADD  CONSTRAINT [DF_Licensee_IsChineseMarket]  DEFAULT ((0)) FOR [IsChineseMarketOnly]
GO
ALTER TABLE [dbo].[Licensee] ADD  CONSTRAINT [DF_Licensee_IsReseller]  DEFAULT ((0)) FOR [IsReseller]
GO
ALTER TABLE [dbo].[LogAction] ADD  DEFAULT ((0)) FOR [Enable]
GO
ALTER TABLE [dbo].[Message] ADD  CONSTRAINT [DF_Message_CreateTime]  DEFAULT (getdate()) FOR [CreateTime]
GO
ALTER TABLE [dbo].[MessageTarget] ADD  DEFAULT ((0)) FOR [LicenseeTypeId]
GO
ALTER TABLE [dbo].[MessageTarget] ADD  DEFAULT ((0)) FOR [PositionId]
GO
ALTER TABLE [dbo].[UserInfo] ADD  DEFAULT (getdate()) FOR [CreateTime]
GO
ALTER TABLE [dbo].[UserMessage] ADD  CONSTRAINT [DF_Usermessage_IsRead]  DEFAULT ((0)) FOR [IsRead]
GO
