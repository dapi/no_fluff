namespace :metrics do
  desc 'Generate project metrics dashboard'
  task :dashboard do
    puts '📊 Без Шелухи - Project Metrics Dashboard'
    puts '=' * 60
    puts "Generated on: #{Date.today}"
    puts "Environment: #{Rails.env}"
    puts

    # Specifications Metrics
    puts '📋 SPECIFICATIONS METRICS'
    puts '-' * 30

    specs_dir = Rails.root.join('docs/Specs')
    spec_files = Dir.glob("#{specs_dir}/*_Specification.md")

    if spec_files.empty?
      puts '📭 No specifications found'
    else
      total_specs = spec_files.length
      status_counts = Hash.new(0)

      spec_files.each do |file|
        content = File.read(file)
        status_match = content.match(/^## Статус: (.+)$/)
        status = status_match ? status_match[1] : 'unknown'
        status_counts[status] += 1
      end

      puts "Total specifications: #{total_specs}"
      puts

      # Status breakdown with colors
      status_icons = {
        'draft' => '🟡',
        'business_review' => '🟠',
        'need_plan' => '🔵',
        'tech_review' => '🟣',
        'approved' => '🟢',
        'in_progress' => '🔷',
        'testing' => '🔴',
        'implemented' => '🔵',
        'delivered' => '🟤',
        'unknown' => '❓'
      }

      status_counts.each do |status, count|
        icon = status_icons[status] || '❓'
        percentage = (count.to_f / total_specs * 100).round(1)
        puts "  #{icon} #{status.gsub('_', ' ').titleize}: #{count} (#{percentage}%)"
      end

      # Health metrics
      complete_specs = status_counts['implemented'].to_i + status_counts['delivered'].to_i
      completion_rate = (complete_specs.to_f / total_specs * 100).round(1)

      puts
      puts "📈 Completion Rate: #{completion_rate}%"

      if completion_rate >= 80
        puts '✅ Excellent progress!'
      elsif completion_rate >= 60
        puts '👍 Good progress'
      elsif completion_rate >= 40
        puts '⚠️  Moderate progress'
      else
        puts '❌ Needs attention'
      end
    end

    puts
    puts

    # Implementation Plans Metrics
    puts '🔧 IMPLEMENTATION PLANS METRICS'
    puts '-' * 35

    impl_dir = Rails.root.join('docs/Implementation')
    impl_files = Dir.glob("#{impl_dir}/Spec_*.md")

    if impl_files.empty?
      puts '📭 No implementation plans found'
    else
      total_plans = impl_files.length
      completed_plans = 0
      in_progress_plans = 0

      impl_files.each do |file|
        content = File.read(file)
        # Count completed checkboxes
        checked_boxes = content.scan(/\[x\]/).length
        total_boxes = content.scan(/\[[x ]\]/).length

        if total_boxes > 0
          completion_percentage = (checked_boxes.to_f / total_boxes * 100).round(1)
          if completion_percentage >= 90
            completed_plans += 1
          elsif completion_percentage > 0
            in_progress_plans += 1
          end
        end
      end

      puts "Total implementation plans: #{total_plans}"
      puts "  ✅ Completed plans: #{completed_plans}"
      puts "  🔄 In-progress plans: #{in_progress_plans}"
      puts "  ⏳ Not started: #{total_plans - completed_plans - in_progress_plans}"
    end

    puts
    puts

    # Code Quality Metrics (if available)
    puts '🧪 CODE QUALITY METRICS'
    puts '-' * 25

    if File.exist?('.rubocop.yml')
      # Get RuboCop offenses (approximate)
      begin
        # This is a simplified check - in real implementation you'd parse RuboCop output
        puts '📝 RuboCop status: Configured'
        puts "💡 Run 'rubocop' for detailed offense report"
      rescue
        puts '⚠️  RuboCop check failed'
      end
    else
      puts '⚠️  RuboCop not configured'
    end

    # Test files count
    test_dirs = [ 'test', 'spec' ]
    total_test_files = 0

    test_dirs.each do |test_dir|
      dir_path = Rails.root.join(test_dir)
      if Dir.exist?(dir_path)
        test_files = Dir.glob("#{dir_path}/**/*_test.rb").length + Dir.glob("#{dir_path}/**/*_spec.rb").length
        total_test_files += test_files
      end
    end

    puts "🧪 Test files: #{total_test_files}"

    # Ruby files count for test coverage ratio
    ruby_files = Dir.glob(Rails.root.join('app/**/*.rb')).length
    if ruby_files > 0
      test_coverage_ratio = (total_test_files.to_f / ruby_files * 100).round(1)
      puts "📊 Test/Code ratio: #{test_coverage_ratio}% (#{total_test_files} tests / #{ruby_files} files)"
    end

    puts
    puts

    # Project Health Score
    puts '🏥 PROJECT HEALTH SCORE'
    puts '-' * 25

    health_score = calculate_health_score
    puts "Overall Health Score: #{health_score}/100"

    if health_score >= 90
      puts '✅ Excellent - Project is very healthy!'
    elsif health_score >= 75
      puts '👍 Good - Project is healthy'
    elsif health_score >= 60
      puts '⚠️  Fair - Project needs some attention'
    else
      puts '❌ Poor - Project needs immediate attention'
    end

    puts
    puts

    # Recommendations
    puts '💡 RECOMMENDATIONS'
    puts '-' * 20

    generate_recommendations(status_counts, total_specs, impl_files)

    puts
    puts '=' * 60
    puts '📊 Dashboard generated successfully!'
    puts "💡 Run 'rake metrics:detailed' for more detailed analysis"
  end

  desc 'Generate detailed metrics analysis'
  task :detailed do
    puts '📊 Без Шелухи - Detailed Metrics Analysis'
    puts '=' * 60
    puts "Generated on: #{Date.today}"
    puts

    # Specification quality analysis
    puts '🔍 SPECIFICATION QUALITY ANALYSIS'
    puts '-' * 40

    specs_dir = Rails.root.join('docs/Specs')
    spec_files = Dir.glob("#{specs_dir}/*_Specification.md")

    quality_metrics = {
      with_business_context: 0,
      with_metrics: 0,
      with_risks: 0,
      with_dependencies: 0,
      complete_specs: 0
    }

    spec_files.each do |file|
      content = File.read(file)

      quality_metrics[:with_business_context] += 1 if content.include?('## Бизнес-контекст')
      quality_metrics[:with_metrics] += 1 if content.include?('### Метрики успеха:')
      quality_metrics[:with_risks] += 1 if content.include?('### Риски реализации:')
      quality_metrics[:with_dependencies] += 1 if content.include?('### Блокирующие зависимости:')
      quality_metrics[:complete_specs] += 1 if content.match(/^## Статус: (implemented|delivered)$/)
    end

    total_specs = spec_files.length

    puts "Business Context Coverage: #{(quality_metrics[:with_business_context].to_f / total_specs * 100).round(1)}%"
    puts "Success Metrics Coverage: #{(quality_metrics[:with_metrics].to_f / total_specs * 100).round(1)}%"
    puts "Risk Assessment Coverage: #{(quality_metrics[:with_risks].to_f / total_specs * 100).round(1)}%"
    puts "Dependencies Coverage: #{(quality_metrics[:with_dependencies].to_f / total_specs * 100).round(1)}%"
    puts "Completion Rate: #{(quality_metrics[:complete_specs].to_f / total_specs * 100).round(1)}%"

    puts
    puts

    # Timeline analysis
    puts '📅 TIMELINE ANALYSIS'
    puts '-' * 20

    impl_dir = Rails.root.join('docs/Implementation')
    impl_files = Dir.glob("#{impl_dir}/Spec_*.md")

    if impl_files.any?
      puts "Implementation Plans Created: #{impl_files.length}"

      # Estimate completion time based on checkbox completion
      total_checkboxes = 0
      completed_checkboxes = 0

      impl_files.each do |file|
        content = File.read(file)
        file_total = content.scan(/\[[x ]\]/).length
        file_completed = content.scan(/\[x\]/).length

        total_checkboxes += file_total
        completed_checkboxes += file_completed
      end

      if total_checkboxes > 0
        overall_completion = (completed_checkboxes.to_f / total_checkboxes * 100).round(1)
        puts "Overall Implementation Progress: #{overall_completion}%"

        # Estimate remaining work (rough calculation)
        remaining_items = total_checkboxes - completed_checkboxes
        estimated_days = (remaining_items * 0.5).round # Assume 0.5 days per item
        puts "Estimated Remaining Work: #{estimated_days} days"
      end
    end

    puts
    puts

    # Risk assessment
    puts '⚠️  RISK ASSESSMENT'
    puts '-' * 18

    risks = []

    # Check for specifications without business metrics
    specs_without_metrics = total_specs - quality_metrics[:with_metrics]
    if specs_without_metrics > 0
      risks << "#{specs_without_metrics} specifications lack business metrics"
    end

    # Check for implementation plans
    if impl_files.length < total_specs * 0.8
      risks << "Insufficient implementation plans (#{impl_files.length}/#{total_specs})"
    end

    # Check completion rate
    completion_rate = (quality_metrics[:complete_specs].to_f / total_specs * 100)
    if completion_rate < 50
      risks << "Low completion rate (#{completion_rate.round(1)}%)"
    end

    if risks.empty?
      puts '✅ No significant risks identified'
    else
      puts '⚠️  Identified Risks:'
      risks.each { |risk| puts "   • #{risk}" }
    end

    puts
    puts '=' * 60
  end

  private

  def calculate_health_score
    # Simplified health score calculation
    score = 50 # Base score

    # Add points for specifications
    specs_dir = Rails.root.join('docs/Specs')
    spec_files = Dir.glob("#{specs_dir}/*_Specification.md")

    if spec_files.any?
      score += 20

      # Add points for quality elements
      spec_files.each do |file|
        content = File.read(file)
        score += 2 if content.include?('## Бизнес-контекст')
        score += 2 if content.include?('### Метрики успеха:')
        score += 1 if content.include?('### Риски реализации:')
      end
    end

    # Add points for implementation plans
    impl_dir = Rails.root.join('docs/Implementation')
    impl_files = Dir.glob("#{impl_dir}/Spec_*.md")
    score += 15 if impl_files.any?

    # Cap at 100
    [ score, 100 ].min
  end

  def generate_recommendations(status_counts, total_specs, impl_files)
    recommendations = []

    # Check for stuck specifications
    if status_counts['draft'] > total_specs * 0.3
      recommendations << 'Consider moving draft specifications to business_review'
    end

    if status_counts['business_review'] > 0
      recommendations << 'Schedule business review for pending specifications'
    end

    if status_counts['need_plan'] > total_specs * 0.2
      recommendations << 'Create implementation plans for specifications waiting for plans'
    end

    # Check implementation coverage
    if impl_files.length < total_specs * 0.8
      recommendations << 'Create implementation plans for approved specifications'
    end

    # Check completion
    completed = status_counts['implemented'].to_i + status_counts['delivered'].to_i
    if completed < total_specs * 0.5
      recommendations << 'Focus on completing implemented specifications'
    end

    if recommendations.empty?
      puts '✅ Project is on track! Keep up the good work.'
    else
      recommendations.each { |rec| puts "• #{rec}" }
    end
  end
end
