using System.ComponentModel.DataAnnotations;

namespace QueueApp.Dtos
{
    public class UpdateQueueStatusDto
    {
        [Required]
        public string Status { get; set; } = default!;
    }
}
