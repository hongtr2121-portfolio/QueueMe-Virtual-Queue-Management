using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace QueueAPI.Migrations
{
    /// <inheritdoc />
    public partial class InitSync_20251105 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Restaurants_AdminUserID",
                table: "Restaurants");

            migrationBuilder.AlterColumn<int>(
                name: "AdminUserID",
                table: "Restaurants",
                type: "int",
                nullable: true,
                oldClrType: typeof(int),
                oldType: "int");

            migrationBuilder.AlterColumn<int>(
                name: "EstimatedWaitTime",
                table: "QueueEntries",
                type: "int",
                nullable: true,
                comment: "Thời gian ước tính chờ (phút)",
                oldClrType: typeof(int),
                oldType: "int",
                oldNullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Notes",
                table: "QueueEntries",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "Message",
                table: "Notifications",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.CreateIndex(
                name: "IX_Restaurants_AdminUserID",
                table: "Restaurants",
                column: "AdminUserID",
                unique: true,
                filter: "[AdminUserID] IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Restaurants_AdminUserID",
                table: "Restaurants");

            migrationBuilder.DropColumn(
                name: "Notes",
                table: "QueueEntries");

            migrationBuilder.AlterColumn<int>(
                name: "AdminUserID",
                table: "Restaurants",
                type: "int",
                nullable: false,
                defaultValue: 0,
                oldClrType: typeof(int),
                oldType: "int",
                oldNullable: true);

            migrationBuilder.AlterColumn<int>(
                name: "EstimatedWaitTime",
                table: "QueueEntries",
                type: "int",
                nullable: true,
                oldClrType: typeof(int),
                oldType: "int",
                oldNullable: true,
                oldComment: "Thời gian ước tính chờ (phút)");

            migrationBuilder.AlterColumn<string>(
                name: "Message",
                table: "Notifications",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(500)",
                oldMaxLength: 500);

            migrationBuilder.CreateIndex(
                name: "IX_Restaurants_AdminUserID",
                table: "Restaurants",
                column: "AdminUserID",
                unique: true);
        }
    }
}
