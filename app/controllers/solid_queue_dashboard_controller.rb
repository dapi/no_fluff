class SolidQueueDashboardController < ApplicationController
  def index
    @jobs = SolidQueue::Job.order(created_at: :desc).limit(50)
    @failed_jobs = SolidQueue::Job.where("finished_at IS NULL AND failed_at IS NOT NULL").order(created_at: :desc).limit(20)
    @pending_jobs = SolidQueue::Job.where(finished_at: nil, failed_at: nil).order(created_at: :desc).limit(20)
    @processed_jobs = SolidQueue::Job.where.not(finished_at: nil).order(finished_at: :desc).limit(20)

    # Statistics
    @total_jobs = SolidQueue::Job.count
    @failed_count = SolidQueue::Job.where.not(failed_at: nil).count
    @pending_count = SolidQueue::Job.where(finished_at: nil, failed_at: nil).count
    @processed_count = SolidQueue::Job.where.not(finished_at: nil).count

    # Queue statistics
    @queue_stats = SolidQueue::Job.group(:queue_name).count
  end

  def show_job
    @job = SolidQueue::Job.find(params[:id])
  end

  def retry_job
    job = SolidQueue::Job.find(params[:id])
    if job.failed_at.present?
      job.update!(failed_at: nil, error_message: nil)
      flash[:notice] = "Job ##{job.id} has been queued for retry"
    end
    redirect_back(fallback_location: solid_queue_dashboard_path)
  end

  def delete_job
    job = SolidQueue::Job.find(params[:id])
    job.destroy
    flash[:notice] = "Job ##{job.id} has been deleted"
    redirect_back(fallback_location: solid_queue_dashboard_path)
  end
end