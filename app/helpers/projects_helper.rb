module ProjectsHelper
  def priority_badge_class(priority)
    case priority
    when "P0" then "bg-red-50 text-red-700 border border-red-200"
    when "P1" then "bg-amber-50 text-amber-700 border border-amber-200"
    when "P2" then "bg-slate-100 text-slate-600 border border-slate-200"
    else "bg-slate-100 text-slate-600 border border-slate-200"
    end
  end

  def status_badge_class(status)
    case status
    when "draft" then "bg-slate-100 text-slate-600 border border-slate-200"
    when "in_progress" then "bg-blue-50 text-blue-700 border border-blue-200"
    when "shipped" then "bg-emerald-50 text-emerald-700 border border-emerald-200"
    else "bg-slate-100 text-slate-600 border border-slate-200"
    end
  end

  def render_hypothesis_tree(hypothesis_tree)
    return "" if hypothesis_tree.blank?

    content_tag(:ul, class: "list-disc pl-6 space-y-2") do
      hypothesis_tree.map do |item|
        content_tag(:li, class: "text-gray-700") do
          hypothesis_content = content_tag(:span, item["hypothesis"], class: "font-medium")

          if item["sub_hypotheses"].present?
            sub_list = content_tag(:ul, class: "list-circle pl-6 mt-2 space-y-1") do
              item["sub_hypotheses"].map do |sub|
                content_tag(:li, sub, class: "text-gray-600")
              end.join.html_safe
            end
            hypothesis_content + sub_list
          else
            hypothesis_content
          end
        end
      end.join.html_safe
    end
  end
end
