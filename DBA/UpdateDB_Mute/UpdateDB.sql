USE [bodb_LCC]
GO

/****** Object:  Table [dbo].[MemberBanned]    Script Date: 05/23/2014 14:27:55 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[MemberBanned](
	[MemberBannedId] [int] IDENTITY(1,1) NOT NULL,
	[MemberId] [int] NOT NULL,
	[MemberName] [nvarchar](50) NULL,
	[IsBanned] [bit] NOT NULL,
	[UpdateTime] [smalldatetime] NOT NULL,
 CONSTRAINT [PK_MemberBanned] PRIMARY KEY CLUSTERED 
(
	[MemberBannedId] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

ALTER TABLE [dbo].[ChatUserInRoom]
ADD Muted BIT NULL
ALTER TABLE [dbo].[ChatUserInRoom] ADD  CONSTRAINT [DF_ChatUserInRoom_Muted]  DEFAULT ((0)) FOR [Muted]
GO

ALTER TABLE [dbo].[ChatRoom]
ADD Muted BIT NULL
ALTER TABLE [dbo].[ChatRoom] ADD  CONSTRAINT [DF_ChatRoom_Muted]  DEFAULT ((0)) FOR [Muted]
GO

USE [bodb_LCC]
GO
/****** Object:  UserDefinedFunction [dbo].[strSplit]    Script Date: 05/23/2014 14:12:13 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER FUNCTION  [dbo].[strSplit] ( @string nvarchar( MAX), @splitter CHAR( 1) )
RETURNS @res TABLE ( id INT PRIMARY KEY, rank INT, val nvarchar( 4000) )
AS
BEGIN
     IF SUBSTRING ( @string, len ( @string), 1)<>@splitter
          SET @string= @string+@splitter
     DECLARE @start INT, @word nvarchar(4000), @charindex INT, @i INT
     SET @i=1
     SET @start=1
     SET @charindex= CHARINDEX( @splitter, @string, @start)
     WHILE (@charindex <> 0)BEGIN
          SET @word= SUBSTRING( @string, @start, @charindex - @start)
          SET @start= @charindex +1
          SET @charindex= CHARINDEX( @splitter, @string, @start)
          INSERT INTO @res  VALUES ( @start, @i, @word)
          SET @i=@i+1
     END
     RETURN
END



