USE [master]
GO
/****** Object:  Database [Attendsystem]    Script Date: 12/19/2025 7:25:03 PM ******/
CREATE DATABASE [Attendsystem]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'Attendsystem', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\Attendsystem.mdf' , SIZE = 8192KB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'Attendsystem_log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\Attendsystem_log.ldf' , SIZE = 8192KB , MAXSIZE = 2048GB , FILEGROWTH = 65536KB )
 WITH CATALOG_COLLATION = DATABASE_DEFAULT, LEDGER = OFF
GO
ALTER DATABASE [Attendsystem] SET COMPATIBILITY_LEVEL = 160
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [Attendsystem].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [Attendsystem] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [Attendsystem] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [Attendsystem] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [Attendsystem] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [Attendsystem] SET ARITHABORT OFF 
GO
ALTER DATABASE [Attendsystem] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [Attendsystem] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [Attendsystem] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [Attendsystem] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [Attendsystem] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [Attendsystem] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [Attendsystem] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [Attendsystem] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [Attendsystem] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [Attendsystem] SET  ENABLE_BROKER 
GO
ALTER DATABASE [Attendsystem] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [Attendsystem] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [Attendsystem] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [Attendsystem] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [Attendsystem] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [Attendsystem] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [Attendsystem] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [Attendsystem] SET RECOVERY FULL 
GO
ALTER DATABASE [Attendsystem] SET  MULTI_USER 
GO
ALTER DATABASE [Attendsystem] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [Attendsystem] SET DB_CHAINING OFF 
GO
ALTER DATABASE [Attendsystem] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [Attendsystem] SET TARGET_RECOVERY_TIME = 60 SECONDS 
GO
ALTER DATABASE [Attendsystem] SET DELAYED_DURABILITY = DISABLED 
GO
ALTER DATABASE [Attendsystem] SET ACCELERATED_DATABASE_RECOVERY = OFF  
GO
EXEC sys.sp_db_vardecimal_storage_format N'Attendsystem', N'ON'
GO
ALTER DATABASE [Attendsystem] SET QUERY_STORE = ON
GO
ALTER DATABASE [Attendsystem] SET QUERY_STORE (OPERATION_MODE = READ_WRITE, CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30), DATA_FLUSH_INTERVAL_SECONDS = 900, INTERVAL_LENGTH_MINUTES = 60, MAX_STORAGE_SIZE_MB = 1000, QUERY_CAPTURE_MODE = AUTO, SIZE_BASED_CLEANUP_MODE = AUTO, MAX_PLANS_PER_QUERY = 200, WAIT_STATS_CAPTURE_MODE = ON)
GO
USE [Attendsystem]
GO
/****** Object:  Table [dbo].[admin]    Script Date: 12/19/2025 7:25:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[admin](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[username] [nvarchar](50) NOT NULL,
	[password] [nvarchar](50) NOT NULL,
	[full_name] [nvarchar](100) NOT NULL,
	[email] [nvarchar](100) NULL,
	[phone_number] [nvarchar](20) NULL,
	[role] [nvarchar](50) NULL,
	[created_at] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[username] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[attempt_log]    Script Date: 12/19/2025 7:25:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[attempt_log](
	[log_id] [int] IDENTITY(1,1) NOT NULL,
	[student_id] [int] NULL,
	[session_id] [int] NULL,
	[status] [nvarchar](50) NULL,
	[image_metadata] [nvarchar](max) NULL,
	[attempt_time] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[log_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[attendance_record]    Script Date: 12/19/2025 7:25:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[attendance_record](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[session_id] [int] NULL,
	[student_id] [int] NULL,
	[method] [nvarchar](50) NULL,
	[status] [nvarchar](50) NULL,
	[marked_at] [datetime] NULL,
	[last_updated] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[camera]    Script Date: 12/19/2025 7:25:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[camera](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[location] [nvarchar](100) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[class_session]    Script Date: 12/19/2025 7:25:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[class_session](
	[session_id] [int] IDENTITY(1,1) NOT NULL,
	[course_id] [int] NULL,
	[instructor_id] [int] NULL,
	[classroom_id] [int] NULL,
	[session_type] [nvarchar](50) NULL,
	[session_start] [datetime] NULL,
	[session_end] [datetime] NULL,
	[session_status] [nvarchar](20) NULL,
	[attendance_start] [datetime] NULL,
	[attendance_end] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[session_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[classroom]    Script Date: 12/19/2025 7:25:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[classroom](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[building] [nvarchar](50) NULL,
	[capacity] [int] NULL,
	[camera_id] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[course]    Script Date: 12/19/2025 7:25:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[course](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[name] [nvarchar](100) NOT NULL,
	[credit_hours] [int] NULL,
	[department_id] [int] NULL,
	[instructor_id] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[course_assignment]    Script Date: 12/19/2025 7:25:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[course_assignment](
	[assignment_id] [int] IDENTITY(1,1) NOT NULL,
	[course_id] [int] NULL,
	[instructor_id] [int] NULL,
	[role] [nvarchar](50) NULL,
	[semester] [nvarchar](20) NULL,
	[academic_year] [nvarchar](20) NULL,
PRIMARY KEY CLUSTERED 
(
	[assignment_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[department]    Script Date: 12/19/2025 7:25:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[department](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[name] [nvarchar](100) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[enrollment]    Script Date: 12/19/2025 7:25:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[enrollment](
	[enrollment_id] [int] IDENTITY(1,1) NOT NULL,
	[student_id] [int] NULL,
	[course_id] [int] NULL,
	[status] [nvarchar](50) NULL,
	[enrolled_date] [date] NULL,
	[semester] [nvarchar](20) NULL,
	[academic_year] [nvarchar](20) NULL,
PRIMARY KEY CLUSTERED 
(
	[enrollment_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[instructor]    Script Date: 12/19/2025 7:25:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[instructor](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[first_name] [nvarchar](50) NOT NULL,
	[last_name] [nvarchar](50) NOT NULL,
	[email] [nvarchar](100) NULL,
	[phone_number] [nvarchar](20) NULL,
	[department_id] [int] NULL,
	[password] [nvarchar](255) NULL,
	[role] [nvarchar](50) NULL,
	[username] [nvarchar](50) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[email] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[student]    Script Date: 12/19/2025 7:25:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[student](
	[id] [int] NOT NULL,
	[first_name] [nvarchar](50) NOT NULL,
	[last_name] [nvarchar](50) NOT NULL,
	[email] [nvarchar](100) NULL,
	[phone_number] [nvarchar](20) NULL,
	[password] [nvarchar](255) NULL,
	[date_of_birth] [date] NULL,
	[academic_year] [nvarchar](20) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[email] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[admin] ADD  DEFAULT ('Moderator') FOR [role]
GO
ALTER TABLE [dbo].[admin] ADD  DEFAULT (getdate()) FOR [created_at]
GO
ALTER TABLE [dbo].[attempt_log] ADD  DEFAULT (getdate()) FOR [attempt_time]
GO
ALTER TABLE [dbo].[attendance_record] ADD  DEFAULT ('FaceID') FOR [method]
GO
ALTER TABLE [dbo].[attendance_record] ADD  DEFAULT (getdate()) FOR [marked_at]
GO
ALTER TABLE [dbo].[attendance_record] ADD  DEFAULT (getdate()) FOR [last_updated]
GO
ALTER TABLE [dbo].[class_session] ADD  DEFAULT ('Scheduled') FOR [session_status]
GO
ALTER TABLE [dbo].[course_assignment] ADD  DEFAULT ('Lecturer') FOR [role]
GO
ALTER TABLE [dbo].[enrollment] ADD  DEFAULT ('Enrolled') FOR [status]
GO
ALTER TABLE [dbo].[enrollment] ADD  DEFAULT (getdate()) FOR [enrolled_date]
GO
ALTER TABLE [dbo].[instructor] ADD  DEFAULT ('admin123') FOR [password]
GO
ALTER TABLE [dbo].[student] ADD  DEFAULT ('123456') FOR [password]
GO
ALTER TABLE [dbo].[attempt_log]  WITH CHECK ADD FOREIGN KEY([session_id])
REFERENCES [dbo].[class_session] ([session_id])
GO
ALTER TABLE [dbo].[attempt_log]  WITH CHECK ADD FOREIGN KEY([student_id])
REFERENCES [dbo].[student] ([id])
GO
ALTER TABLE [dbo].[attendance_record]  WITH CHECK ADD FOREIGN KEY([session_id])
REFERENCES [dbo].[class_session] ([session_id])
GO
ALTER TABLE [dbo].[attendance_record]  WITH CHECK ADD FOREIGN KEY([student_id])
REFERENCES [dbo].[student] ([id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[class_session]  WITH CHECK ADD FOREIGN KEY([classroom_id])
REFERENCES [dbo].[classroom] ([id])
GO
ALTER TABLE [dbo].[class_session]  WITH CHECK ADD FOREIGN KEY([course_id])
REFERENCES [dbo].[course] ([id])
GO
ALTER TABLE [dbo].[class_session]  WITH CHECK ADD FOREIGN KEY([instructor_id])
REFERENCES [dbo].[instructor] ([id])
GO
ALTER TABLE [dbo].[classroom]  WITH CHECK ADD  CONSTRAINT [FK_Classroom_Camera] FOREIGN KEY([camera_id])
REFERENCES [dbo].[camera] ([id])
GO
ALTER TABLE [dbo].[classroom] CHECK CONSTRAINT [FK_Classroom_Camera]
GO
ALTER TABLE [dbo].[course]  WITH CHECK ADD FOREIGN KEY([department_id])
REFERENCES [dbo].[department] ([id])
GO
ALTER TABLE [dbo].[course]  WITH CHECK ADD FOREIGN KEY([instructor_id])
REFERENCES [dbo].[instructor] ([id])
GO
ALTER TABLE [dbo].[course_assignment]  WITH CHECK ADD FOREIGN KEY([course_id])
REFERENCES [dbo].[course] ([id])
GO
ALTER TABLE [dbo].[course_assignment]  WITH CHECK ADD FOREIGN KEY([instructor_id])
REFERENCES [dbo].[instructor] ([id])
GO
ALTER TABLE [dbo].[enrollment]  WITH CHECK ADD FOREIGN KEY([course_id])
REFERENCES [dbo].[course] ([id])
GO
ALTER TABLE [dbo].[enrollment]  WITH CHECK ADD FOREIGN KEY([student_id])
REFERENCES [dbo].[student] ([id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[instructor]  WITH CHECK ADD FOREIGN KEY([department_id])
REFERENCES [dbo].[department] ([id])
GO
USE [master]
GO
ALTER DATABASE [Attendsystem] SET  READ_WRITE 
GO