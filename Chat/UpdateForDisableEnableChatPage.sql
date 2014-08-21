ALTER TABLE [dbo].[ChatRoom]
ADD Disabled BIT NULL
ALTER TABLE [dbo].[ChatRoom] ADD  CONSTRAINT [DF_ChatRoom_Disabled]  DEFAULT ((0)) FOR [Disabled]
GO