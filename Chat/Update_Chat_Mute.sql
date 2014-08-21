--ALTER TABLE [dbo].[ChatUserInRoom]
--ADD Muted BIT NULL
--ALTER TABLE [dbo].[ChatUserInRoom] ADD  CONSTRAINT [DF_ChatUserInRoom_Muted]  DEFAULT ((0)) FOR [Muted]
--GO

ALTER TABLE [dbo].[ChatRoom]
ADD Muted BIT NULL
ALTER TABLE [dbo].[ChatRoom] ADD  CONSTRAINT [DF_ChatRoom_Muted]  DEFAULT ((0)) FOR [Muted]
GO