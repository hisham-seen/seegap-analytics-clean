'use client'

import { useState, useEffect } from 'react'
import { 
  ChartBarIcon, 
  UsersIcon, 
  EyeIcon, 
  CursorArrowRaysIcon,
  TrophyIcon,
  GiftIcon
} from '@heroicons/react/24/outline'

// Mock data for demonstration
const mockMetrics = {
  pageViews: { value: 12543, change: 12.5, period: 'vs last month' },
  uniqueVisitors: { value: 3421, change: 8.2, period: 'vs last month' },
  sessions: { value: 5678, change: -2.1, period: 'vs last month' },
  loyaltyPoints: { value: 45231, change: 23.4, period: 'vs last month' },
  rewardsRedeemed: { value: 156, change: 18.7, period: 'vs last month' },
  conversionRate: { value: 3.2, change: 5.1, period: 'vs last month' }
}

const mockChartData = {
  labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
  datasets: [
    {
      label: 'Page Views',
      data: [1200, 1900, 3000, 5000, 2000, 3000],
      borderColor: 'rgb(59, 130, 246)',
      backgroundColor: 'rgba(59, 130, 246, 0.1)',
    },
    {
      label: 'Unique Visitors',
      data: [800, 1200, 1800, 2800, 1400, 2100],
      borderColor: 'rgb(16, 185, 129)',
      backgroundColor: 'rgba(16, 185, 129, 0.1)',
    }
  ]
}

interface MetricCardProps {
  title: string
  value: string | number
  change: number
  period: string
  icon: React.ComponentType<{ className?: string }>
  format?: 'number' | 'percentage' | 'currency'
}

function MetricCard({ title, value, change, period, icon: Icon, format = 'number' }: MetricCardProps) {
  const formatValue = (val: string | number) => {
    if (format === 'percentage') return `${val}%`
    if (format === 'currency') return `$${val}`
    if (typeof val === 'number') return val.toLocaleString()
    return val
  }

  const isPositive = change > 0
  const changeColor = isPositive ? 'text-success-600' : 'text-error-600'
  const changeIcon = isPositive ? '↗' : '↘'

  return (
    <div className="metric-card">
      <div className="flex items-center justify-between">
        <div>
          <p className="metric-label">{title}</p>
          <p className="metric-value">{formatValue(value)}</p>
          <p className={`metric-change ${changeColor}`}>
            <span className="mr-1">{changeIcon}</span>
            {Math.abs(change)}% {period}
          </p>
        </div>
        <div className="flex-shrink-0">
          <Icon className="h-8 w-8 text-gray-400" />
        </div>
      </div>
    </div>
  )
}

export default function Dashboard() {
  const [isLoading, setIsLoading] = useState(true)
  const [selectedPeriod, setSelectedPeriod] = useState('30d')

  useEffect(() => {
    // Simulate loading
    const timer = setTimeout(() => setIsLoading(false), 1000)
    return () => clearTimeout(timer)
  }, [])

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="loading-spinner mx-auto mb-4"></div>
          <p className="text-gray-600">Loading your analytics dashboard...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-6">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">Analytics Dashboard</h1>
              <p className="mt-1 text-sm text-gray-500">
                Track your website performance and loyalty rewards
              </p>
            </div>
            <div className="flex items-center space-x-4">
              <select 
                value={selectedPeriod}
                onChange={(e) => setSelectedPeriod(e.target.value)}
                className="form-input"
              >
                <option value="7d">Last 7 days</option>
                <option value="30d">Last 30 days</option>
                <option value="90d">Last 90 days</option>
                <option value="1y">Last year</option>
              </select>
              <button className="btn-primary">
                Export Report
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Metrics Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
          <MetricCard
            title="Page Views"
            value={mockMetrics.pageViews.value}
            change={mockMetrics.pageViews.change}
            period={mockMetrics.pageViews.period}
            icon={EyeIcon}
          />
          <MetricCard
            title="Unique Visitors"
            value={mockMetrics.uniqueVisitors.value}
            change={mockMetrics.uniqueVisitors.change}
            period={mockMetrics.uniqueVisitors.period}
            icon={UsersIcon}
          />
          <MetricCard
            title="Sessions"
            value={mockMetrics.sessions.value}
            change={mockMetrics.sessions.change}
            period={mockMetrics.sessions.period}
            icon={CursorArrowRaysIcon}
          />
          <MetricCard
            title="Loyalty Points Earned"
            value={mockMetrics.loyaltyPoints.value}
            change={mockMetrics.loyaltyPoints.change}
            period={mockMetrics.loyaltyPoints.period}
            icon={TrophyIcon}
          />
          <MetricCard
            title="Rewards Redeemed"
            value={mockMetrics.rewardsRedeemed.value}
            change={mockMetrics.rewardsRedeemed.change}
            period={mockMetrics.rewardsRedeemed.period}
            icon={GiftIcon}
          />
          <MetricCard
            title="Conversion Rate"
            value={mockMetrics.conversionRate.value}
            change={mockMetrics.conversionRate.change}
            period={mockMetrics.conversionRate.period}
            icon={ChartBarIcon}
            format="percentage"
          />
        </div>

        {/* Charts Section */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
          {/* Traffic Chart */}
          <div className="card">
            <div className="card-header">
              <h3 className="text-lg font-medium text-gray-900">Traffic Overview</h3>
              <p className="text-sm text-gray-500">Page views and unique visitors over time</p>
            </div>
            <div className="card-body">
              <div className="h-64 flex items-center justify-center bg-gray-50 rounded-lg">
                <p className="text-gray-500">Chart.js integration will be added here</p>
              </div>
            </div>
          </div>

          {/* Loyalty Performance */}
          <div className="card">
            <div className="card-header">
              <h3 className="text-lg font-medium text-gray-900">Loyalty Performance</h3>
              <p className="text-sm text-gray-500">Points earned and rewards redeemed</p>
            </div>
            <div className="card-body">
              <div className="h-64 flex items-center justify-center bg-gray-50 rounded-lg">
                <p className="text-gray-500">Loyalty chart will be added here</p>
              </div>
            </div>
          </div>
        </div>

        {/* Recent Activity */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Top Pages */}
          <div className="card">
            <div className="card-header">
              <h3 className="text-lg font-medium text-gray-900">Top Pages</h3>
            </div>
            <div className="card-body p-0">
              <div className="overflow-hidden">
                <table className="table">
                  <thead className="table-header">
                    <tr>
                      <th className="table-header-cell">Page</th>
                      <th className="table-header-cell">Views</th>
                      <th className="table-header-cell">Points Earned</th>
                    </tr>
                  </thead>
                  <tbody className="table-body">
                    <tr className="table-row">
                      <td className="table-cell">
                        <div className="text-sm font-medium text-gray-900">/home</div>
                        <div className="text-sm text-gray-500">Homepage</div>
                      </td>
                      <td className="table-cell">3,247</td>
                      <td className="table-cell">6,494</td>
                    </tr>
                    <tr className="table-row">
                      <td className="table-cell">
                        <div className="text-sm font-medium text-gray-900">/products</div>
                        <div className="text-sm text-gray-500">Product catalog</div>
                      </td>
                      <td className="table-cell">2,156</td>
                      <td className="table-cell">4,312</td>
                    </tr>
                    <tr className="table-row">
                      <td className="table-cell">
                        <div className="text-sm font-medium text-gray-900">/about</div>
                        <div className="text-sm text-gray-500">About page</div>
                      </td>
                      <td className="table-cell">1,432</td>
                      <td className="table-cell">2,864</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>

          {/* Recent Rewards */}
          <div className="card">
            <div className="card-header">
              <h3 className="text-lg font-medium text-gray-900">Recent Reward Redemptions</h3>
            </div>
            <div className="card-body p-0">
              <div className="overflow-hidden">
                <table className="table">
                  <thead className="table-header">
                    <tr>
                      <th className="table-header-cell">Reward</th>
                      <th className="table-header-cell">Points</th>
                      <th className="table-header-cell">Status</th>
                    </tr>
                  </thead>
                  <tbody className="table-body">
                    <tr className="table-row">
                      <td className="table-cell">
                        <div className="text-sm font-medium text-gray-900">10% Discount</div>
                        <div className="text-sm text-gray-500">2 hours ago</div>
                      </td>
                      <td className="table-cell">100</td>
                      <td className="table-cell">
                        <span className="badge-success">Redeemed</span>
                      </td>
                    </tr>
                    <tr className="table-row">
                      <td className="table-cell">
                        <div className="text-sm font-medium text-gray-900">Free Shipping</div>
                        <div className="text-sm text-gray-500">5 hours ago</div>
                      </td>
                      <td className="table-cell">50</td>
                      <td className="table-cell">
                        <span className="badge-success">Redeemed</span>
                      </td>
                    </tr>
                    <tr className="table-row">
                      <td className="table-cell">
                        <div className="text-sm font-medium text-gray-900">Premium Access</div>
                        <div className="text-sm text-gray-500">1 day ago</div>
                      </td>
                      <td className="table-cell">500</td>
                      <td className="table-cell">
                        <span className="badge-warning">Pending</span>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  )
}
