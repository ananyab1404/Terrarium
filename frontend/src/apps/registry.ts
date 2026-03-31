import {
  Activity,
  AppWindow,
  AreaChart,
  Boxes,
  Container,
  FileCode2,
  GitBranch,
  ListTree,
  Radio,
  Settings,
} from 'lucide-react'
import { lazy } from 'react'

import type { AppId, Geometry } from '@/types/app'

export interface AppDefinition {
  id: AppId
  title: string
  icon: React.ComponentType<{ className?: string }>
  component: React.LazyExoticComponent<() => JSX.Element>
  defaultSize: Pick<Geometry, 'width' | 'height'>
  minSize: Pick<Geometry, 'width' | 'height'>
  defaultPosition: 'center' | 'cascade'
  multiInstance: boolean
  description: string
}

export const appDefinitions: AppDefinition[] = [
  {
    id: 'live-feed',
    title: 'Live Event Feed',
    icon: Radio,
    component: lazy(() => import('@/apps/live-feed')),
    defaultSize: { width: 480, height: 640 },
    minSize: { width: 320, height: 400 },
    defaultPosition: 'cascade',
    multiInstance: true,
    description: 'Real-time platform event stream',
  },
  {
    id: 'cluster',
    title: 'Cluster Overview',
    icon: AppWindow,
    component: lazy(() => import('@/apps/cluster')),
    defaultSize: { width: 900, height: 560 },
    minSize: { width: 600, height: 400 },
    defaultPosition: 'center',
    multiInstance: false,
    description: 'Node capacity and autoscaler state',
  },
  {
    id: 'heatmap',
    title: 'Node Heatmap',
    icon: Boxes,
    component: lazy(() => import('@/apps/heatmap')),
    defaultSize: { width: 760, height: 520 },
    minSize: { width: 500, height: 360 },
    defaultPosition: 'cascade',
    multiInstance: true,
    description: 'Utilization heatmap across nodes',
  },
  {
    id: 'network',
    title: 'Network Topology',
    icon: GitBranch,
    component: lazy(() => import('@/apps/network')),
    defaultSize: { width: 800, height: 600 },
    minSize: { width: 500, height: 400 },
    defaultPosition: 'center',
    multiInstance: false,
    description: 'Live cluster topology graph',
  },
  {
    id: 'jobs',
    title: 'Job Runner',
    icon: ListTree,
    component: lazy(() => import('@/apps/jobs')),
    defaultSize: { width: 1000, height: 660 },
    minSize: { width: 700, height: 480 },
    defaultPosition: 'center',
    multiInstance: false,
    description: 'Job lifecycle and timeline details',
  },
  {
    id: 'logs',
    title: 'Log Viewer',
    icon: FileCode2,
    component: lazy(() => import('@/apps/logs')),
    defaultSize: { width: 860, height: 580 },
    minSize: { width: 500, height: 360 },
    defaultPosition: 'cascade',
    multiInstance: true,
    description: 'Virtualized streaming log console',
  },
  {
    id: 'upload',
    title: 'Function Upload',
    icon: Activity,
    component: lazy(() => import('@/apps/upload')),
    defaultSize: { width: 640, height: 520 },
    minSize: { width: 480, height: 400 },
    defaultPosition: 'center',
    multiInstance: false,
    description: 'Artifact upload and deploy flow',
  },
  {
    id: 'containers',
    title: 'Container Registry',
    icon: Container,
    component: lazy(() => import('@/apps/containers')),
    defaultSize: { width: 720, height: 500 },
    minSize: { width: 500, height: 360 },
    defaultPosition: 'center',
    multiInstance: false,
    description: 'Container image registry tooling',
  },
  {
    id: 'analytics',
    title: 'Analytics',
    icon: AreaChart,
    component: lazy(() => import('@/apps/analytics')),
    defaultSize: { width: 1000, height: 680 },
    minSize: { width: 700, height: 480 },
    defaultPosition: 'cascade',
    multiInstance: true,
    description: 'Latency and throughput insights',
  },
  {
    id: 'settings',
    title: 'Settings',
    icon: Settings,
    component: lazy(() => import('@/apps/settings')),
    defaultSize: { width: 560, height: 480 },
    minSize: { width: 400, height: 360 },
    defaultPosition: 'center',
    multiInstance: false,
    description: 'Desktop and runtime preferences',
  },
]

export const appRegistry: Record<AppId, AppDefinition> = appDefinitions.reduce(
  (acc, app) => {
    acc[app.id] = app
    return acc
  },
  {} as Record<AppId, AppDefinition>,
)
