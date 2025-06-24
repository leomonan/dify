'use client'
import type { FC } from 'react'
import React, { useCallback, useEffect, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useRouter } from 'next/navigation'
import { useDebounce, useDebounceFn } from 'ahooks'
import { groupBy } from 'lodash-es'
import { PlusIcon } from '@heroicons/react/24/solid'
import { RiDraftLine, RiExternalLinkLine, RiFilterLine, RiRefreshLine } from '@remixicon/react'
import AutoDisabledDocument from '../common/document-status-with-action/auto-disabled-document'
import List from './list'
import s from './style.module.css'
import Loading from '@/app/components/base/loading'
import Button from '@/app/components/base/button'
import Input from '@/app/components/base/input'

import { get } from '@/service/base'
import { createDocument, retryAllDocs } from '@/service/datasets'
import { useDatasetDetailContext } from '@/context/dataset-detail'
import { NotionPageSelectorModal } from '@/app/components/base/notion-page-selector'
import type { NotionPage } from '@/models/common'
import type { CreateDocumentReq } from '@/models/datasets'
import { DataSourceType, ProcessMode } from '@/models/datasets'
import IndexFailed from '@/app/components/datasets/common/document-status-with-action/index-failed'
import { useProviderContext } from '@/context/provider-context'
import cn from '@/utils/classnames'
import { useDocumentList, useInvalidDocumentDetailKey, useInvalidDocumentList } from '@/service/knowledge/use-document'
import { useInvalid } from '@/service/use-base'
import { useChildSegmentListKey, useSegmentListKey } from '@/service/knowledge/use-segment'
import useEditDocumentMetadata from '../metadata/hooks/use-edit-dataset-metadata'
import DatasetMetadataDrawer from '../metadata/metadata-dataset/dataset-metadata-drawer'
import StatusWithAction from '../common/document-status-with-action/status-with-action'
import { useDocLink } from '@/context/i18n'
import Toast from '@/app/components/base/toast'
import type { DocumentDisplayStatus, DocumentIndexingStatus } from '@/models/datasets'
import { DisplayStatusList } from '@/models/datasets'
import { useAppContext } from '@/context/app-context'

const FolderPlusIcon = ({ className }: React.SVGProps<SVGElement>) => {
  return <svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg" className={className ?? ''}>
    <path d="M10.8332 5.83333L9.90355 3.9741C9.63601 3.439 9.50222 3.17144 9.30265 2.97597C9.12615 2.80311 8.91344 2.67164 8.6799 2.59109C8.41581 2.5 8.11668 2.5 7.51841 2.5H4.33317C3.39975 2.5 2.93304 2.5 2.57652 2.68166C2.26292 2.84144 2.00795 3.09641 1.84816 3.41002C1.6665 3.76654 1.6665 4.23325 1.6665 5.16667V5.83333M1.6665 5.83333H14.3332C15.7333 5.83333 16.4334 5.83333 16.9681 6.10582C17.4386 6.3455 17.821 6.72795 18.0607 7.19836C18.3332 7.73314 18.3332 8.4332 18.3332 9.83333V13.5C18.3332 14.9001 18.3332 15.6002 18.0607 16.135C17.821 16.6054 17.4386 16.9878 16.9681 17.2275C16.4334 17.5 15.7333 17.5 14.3332 17.5H5.6665C4.26637 17.5 3.56631 17.5 3.03153 17.2275C2.56112 16.9878 2.17867 16.6054 1.93899 16.135C1.6665 15.6002 1.6665 14.9001 1.6665 13.5V5.83333ZM9.99984 14.1667V9.16667M7.49984 11.6667H12.4998" stroke="#667085" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
}

const ThreeDotsIcon = ({ className }: React.SVGProps<SVGElement>) => {
  return <svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg" className={className ?? ''}>
    <path d="M5 6.5V5M8.93934 7.56066L10 6.5M10.0103 11.5H11.5103" stroke="#374151" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
}

const NotionIcon = ({ className }: React.SVGProps<SVGElement>) => {
  return <svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg" className={className ?? ''}>
    <g clipPath="url(#clip0_2164_11263)">
      <path fillRule="evenodd" clipRule="evenodd" d="M3.5725 18.2611L1.4229 15.5832C0.905706 14.9389 0.625 14.1466 0.625 13.3312V3.63437C0.625 2.4129 1.60224 1.39936 2.86295 1.31328L12.8326 0.632614C13.5569 0.583164 14.2768 0.775682 14.8717 1.17794L18.3745 3.5462C19.0015 3.97012 19.375 4.66312 19.375 5.40266V16.427C19.375 17.6223 18.4141 18.6121 17.1798 18.688L6.11458 19.3692C5.12958 19.4298 4.17749 19.0148 3.5725 18.2611Z" fill="white" />
      <path d="M7.03006 8.48669V8.35974C7.03006 8.03794 7.28779 7.77104 7.61997 7.74886L10.0396 7.58733L13.3857 12.5147V8.19009L12.5244 8.07528V8.01498C12.5244 7.68939 12.788 7.42074 13.1244 7.4035L15.326 7.29073V7.60755C15.326 7.75628 15.2154 7.88349 15.0638 7.90913L14.534 7.99874V15.0023L13.8691 15.231C13.3136 15.422 12.6952 15.2175 12.3772 14.7377L9.12879 9.83574V14.5144L10.1287 14.7057L10.1147 14.7985C10.0711 15.089 9.82028 15.3087 9.51687 15.3222L7.03006 15.4329C6.99718 15.1205 7.23132 14.841 7.55431 14.807L7.88143 14.7727V8.53453L7.03006 8.48669Z" fill="black" />
      <path fillRule="evenodd" clipRule="evenodd" d="M12.9218 1.85424L2.95217 2.53491C2.35499 2.57568 1.89209 3.05578 1.89209 3.63437V13.3312C1.89209 13.8748 2.07923 14.403 2.42402 14.8325L4.57362 17.5104C4.92117 17.9434 5.46812 18.1818 6.03397 18.147L17.0991 17.4658C17.6663 17.4309 18.1078 16.9762 18.1078 16.427V5.40266C18.1078 5.06287 17.9362 4.74447 17.6481 4.54969L14.1453 2.18143C13.7883 1.94008 13.3564 1.82457 12.9218 1.85424ZM3.44654 3.78562C3.30788 3.68296 3.37387 3.46909 3.54806 3.4566L12.9889 2.77944C13.2897 2.75787 13.5886 2.8407 13.8318 3.01305L15.7261 4.35508C15.798 4.40603 15.7642 4.51602 15.6752 4.52086L5.67742 5.0646C5.37485 5.08106 5.0762 4.99217 4.83563 4.81406L3.44654 3.78562ZM5.20848 6.76919C5.20848 6.4444 5.47088 6.1761 5.80642 6.15783L16.3769 5.58216C16.7039 5.56435 16.9792 5.81583 16.9792 6.13239V15.6783C16.9792 16.0025 16.7177 16.2705 16.3829 16.2896L5.8793 16.8872C5.51537 16.9079 5.20848 16.6283 5.20848 16.2759V6.76919Z" fill="black" />
    </g>
    <defs>
      <clipPath id="clip0_2164_11263">
        <rect width="20" height="20" fill="white" />
      </clipPath>
    </defs>
  </svg>
}

const EmptyElement: FC<{ canAdd: boolean; onClick: () => void; type?: 'upload' | 'sync' }> = ({ canAdd = true, onClick, type = 'upload' }) => {
  const { t } = useTranslation()
  return <div className={s.emptyWrapper}>
    <div className={s.emptyElement}>
      <div className={s.emptySymbolIconWrapper}>
        {type === 'upload' ? <FolderPlusIcon /> : <NotionIcon />}
      </div>
      <span className={s.emptyTitle}>{t('datasetDocuments.list.empty.title')}<ThreeDotsIcon className='relative -left-1.5 -top-3 inline' /></span>
      <div className={s.emptyTip}>
        {t(`datasetDocuments.list.empty.${type}.tip`)}
      </div>
      {type === 'upload' && canAdd && <Button onClick={onClick} className={s.addFileBtn} variant='secondary-accent'>
        <PlusIcon className={s.plusIcon} />{t('datasetDocuments.list.addFile')}
      </Button>}
    </div>
  </div>
}

type IDocumentsProps = {
  datasetId: string
}

export const fetcher = (url: string) => get(url, {}, {})
const DEFAULT_LIMIT = 10

// 映射 DisplayStatus 到 DocumentIndexingStatus 和额外过滤条件
const mapDisplayStatusToIndexingStatus = (displayStatus: DocumentDisplayStatus): {
  status?: DocumentIndexingStatus[]
  archived?: boolean
  enabled?: boolean
} => {
  switch (displayStatus) {
    case 'queuing':
      return { status: ['waiting'] }
    case 'indexing':
      return { status: ['parsing', 'cleaning', 'splitting', 'indexing'] }
    case 'paused':
      return { status: ['paused'] }
    case 'error':
      return { status: ['error'] }
    case 'available':
    case 'enabled':
      return { status: ['completed'], archived: false, enabled: true }
    case 'disabled':
      return { archived: false, enabled: false }
    case 'archived':
      return { archived: true }
    default:
      return {}
  }
}

const Documents: FC<IDocumentsProps> = ({ datasetId }) => {
  const { t } = useTranslation()
  const statusOptions = useMemo(() => {
    return DisplayStatusList
      .filter(status => status !== 'enabled') // 移除"已启用"选项，因为和"可用"重复
      .map(status => ({
        value: status,
        label: t(`datasetDocuments.list.status.${status}`),
      }))
  }, [t])
  const docLink = useDocLink()
  const { plan } = useProviderContext()
  const isFreePlan = plan.type === 'sandbox'
  const [inputValue, setInputValue] = useState<string>('') // the input value
  const [searchValue, setSearchValue] = useState<string>('')
  const [currPage, setCurrPage] = React.useState<number>(0)
  const [limit, setLimit] = useState<number>(DEFAULT_LIMIT)
  const router = useRouter()
  const { dataset } = useDatasetDetailContext()
  const [notionPageSelectorModalVisible, setNotionPageSelectorModalVisible] = useState(false)
  const [timerCanRun, setTimerCanRun] = useState(true)
  const [isRetryingAll, setIsRetryingAll] = useState(false)
  const isDataSourceNotion = dataset?.data_source_type === DataSourceType.NOTION
  const isDataSourceWeb = dataset?.data_source_type === DataSourceType.WEB
  const isDataSourceFile = dataset?.data_source_type === DataSourceType.FILE
  const embeddingAvailable = !!dataset?.embedding_available
  const debouncedSearchValue = useDebounce(searchValue, { wait: 500 })
  // 使用多选
  const [selectedStatuses, setSelectedStatuses] = useState<DocumentDisplayStatus[]>([])
  const [showStatusFilter, setShowStatusFilter] = useState(false)
  const { isCurrentWorkspaceManager } = useAppContext()

  // 点击外部关闭状态过滤器
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as HTMLElement
      if (!target.closest('.status-filter-container'))
        setShowStatusFilter(false)
    }

    if (showStatusFilter) {
      document.addEventListener('mousedown', handleClickOutside)
      return () => document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [showStatusFilter])

  // 处理多个状态的过滤条件
  const getFilterParams = () => {
    if (selectedStatuses.length === 0) return {}

    // 合并所有选中状态的过滤条件
    const statusFilters = selectedStatuses.map(status => mapDisplayStatusToIndexingStatus(status))

    // 合并所有选中状态的索引状态
    const statusValues = Array.from(new Set(statusFilters.flatMap(filter => filter.status || [])))

    // 处理 archived 和 enabled 值
    const archivedValues = statusFilters
      .filter(f => f.archived !== undefined)
      .map(f => f.archived)

    const enabledValues = statusFilters
      .filter(f => f.enabled !== undefined)
      .map(f => f.enabled)

    const result: Record<string, any> = {}

    if (statusValues.length > 0)
      result.status = statusValues

    // 特殊处理archived和enabled值
    // 如果同时选择了archived=true和archived=false的状态，则不应用该过滤器
    if (archivedValues.length > 0) {
      const hasTrue = archivedValues.includes(true)
      const hasFalse = archivedValues.includes(false)

      // 只有当全部为true或全部为false时才应用过滤
      if (hasTrue && !hasFalse)
        result.archived = true
       else if (!hasTrue && hasFalse)
        result.archived = false
      else if ((enabledValues.length > 0) && enabledValues.includes(false))
        result.archived = true
    }

    // 同样处理enabled值
    if (enabledValues.length > 0) {
      const hasTrue = enabledValues.includes(true)
      const hasFalse = enabledValues.includes(false)

      if (hasTrue && !hasFalse)
        result.enabled = true
       else if (!hasTrue && hasFalse)
        result.enabled = false
    }

    return result
  }

  const { data: documentsRes, isFetching: isListLoading } = useDocumentList({
    datasetId,
    query: {
      page: currPage + 1,
      limit,
      keyword: debouncedSearchValue,
      // 使用多选状态条件
      ...getFilterParams(),
    },
    refetchInterval: (isDataSourceNotion && timerCanRun) ? 2500 : 0,
  })

  const invalidDocumentList = useInvalidDocumentList(datasetId)

  useEffect(() => {
    if (documentsRes) {
      const totalPages = Math.ceil(documentsRes.total / limit)
      if (totalPages < currPage + 1)
        setCurrPage(totalPages === 0 ? 0 : totalPages - 1)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [documentsRes])

  const invalidDocumentDetail = useInvalidDocumentDetailKey()
  const invalidChunkList = useInvalid(useSegmentListKey)
  const invalidChildChunkList = useInvalid(useChildSegmentListKey)

  const handleUpdate = useCallback(() => {
    invalidDocumentList()
    invalidDocumentDetail()
    setTimeout(() => {
      invalidChunkList()
      invalidChildChunkList()
    }, 5000)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const documentsWithProgress = useMemo(() => {
    let completedNum = 0
    let percent = 0
    const documentsData = documentsRes?.data?.map((documentItem) => {
      const { indexing_status, completed_segments, total_segments } = documentItem
      const isEmbedded = indexing_status === 'completed' || indexing_status === 'paused' || indexing_status === 'error'

      if (isEmbedded)
        completedNum++

      const completedCount = completed_segments || 0
      const totalCount = total_segments || 0
      if (totalCount === 0 && completedCount === 0) {
        percent = isEmbedded ? 100 : 0
      }
      else {
        const per = Math.round(completedCount * 100 / totalCount)
        percent = per > 100 ? 100 : per
      }
      return {
        ...documentItem,
        percent,
      }
    })
    if (completedNum === documentsRes?.data?.length)
      setTimerCanRun(false)
    return {
      ...documentsRes,
      data: documentsData,
    }
  }, [documentsRes])
  const total = documentsRes?.total || 0

  const routeToDocCreate = () => {
    if (isDataSourceNotion) {
      setNotionPageSelectorModalVisible(true)
      return
    }
    router.push(`/datasets/${datasetId}/documents/create`)
  }

  const handleSaveNotionPageSelected = async (selectedPages: NotionPage[]) => {
    const workspacesMap = groupBy(selectedPages, 'workspace_id')
    const workspaces = Object.keys(workspacesMap).map((workspaceId) => {
      return {
        workspaceId,
        pages: workspacesMap[workspaceId],
      }
    })
    const params = {
      data_source: {
        type: dataset?.data_source_type,
        info_list: {
          data_source_type: dataset?.data_source_type,
          notion_info_list: workspaces.map((workspace) => {
            return {
              workspace_id: workspace.workspaceId,
              pages: workspace.pages.map((page) => {
                const { page_id, page_name, page_icon, type } = page
                return {
                  page_id,
                  page_name,
                  page_icon,
                  type,
                }
              }),
            }
          }),
        },
      },
      indexing_technique: dataset?.indexing_technique,
      process_rule: {
        rules: {},
        mode: ProcessMode.general,
      },
    } as CreateDocumentReq

    await createDocument({
      datasetId,
      body: params,
    })
    invalidDocumentList()
    setTimerCanRun(true)
    // mutateDatasetIndexingStatus(undefined, { revalidate: true })
    setNotionPageSelectorModalVisible(false)
  }

  const documentsList = isDataSourceNotion ? documentsWithProgress?.data : documentsRes?.data
  const [selectedIds, setSelectedIds] = useState<string[]>([])
  const { run: handleSearch } = useDebounceFn(() => {
    setSearchValue(inputValue)
  }, { wait: 500 })

  const handleInputChange = (value: string) => {
    setInputValue(value)
    handleSearch()
  }

  const {
    isShowEditModal: isShowEditMetadataModal,
    showEditModal: showEditMetadataModal,
    hideEditModal: hideEditMetadataModal,
    datasetMetaData,
    handleAddMetaData,
    handleRename,
    handleDeleteMetaData,
    builtInEnabled,
    setBuiltInEnabled,
    builtInMetaData,
  } = useEditDocumentMetadata({
    datasetId,
    dataset,
    onUpdateDocList: invalidDocumentList,
  })

  const handleRetryAll = async () => {
    if (!isCurrentWorkspaceManager) {
      Toast.notify({ type: 'error', message: '没有权限执行此操作' })
      return
    }

    try {
      setIsRetryingAll(true)
      const result = await retryAllDocs({ datasetId })

      if (result.result === 'success') {
        Toast.notify({
          type: 'success',
          message: `批量重试完成！共处理 ${result.total_documents} 个文档，成功 ${result.success_count} 个，失败 ${result.error_count} 个`,
        })
        // 刷新文档列表
        invalidDocumentList()
        setTimerCanRun(true)
      }
 else {
        Toast.notify({ type: 'error', message: result.message || '批量重试失败' })
      }
    }
 catch (error) {
      console.error('Failed to retry all documents:', error)
      Toast.notify({ type: 'error', message: '批量重试失败，请稍后重试' })
    }
 finally {
      setIsRetryingAll(false)
    }
  }

  return (
    <div className='flex h-full flex-col overflow-y-auto'>
      <div className='flex flex-col justify-center gap-1 px-6 pt-4'>
        <h1 className='text-base font-semibold text-text-primary'>{t('datasetDocuments.list.title')}</h1>
        <div className='flex items-center space-x-0.5 text-sm font-normal text-text-tertiary'>
          <span>{t('datasetDocuments.list.desc')}</span>
          <a
            className='flex items-center text-text-accent'
            target='_blank'
            href={docLink('/guides/knowledge-base/integrate-knowledge-within-application')}
          >
            <span>{t('datasetDocuments.list.learnMore')}</span>
            <RiExternalLinkLine className='h-3 w-3' />
          </a>
        </div>
      </div>
      <div className='flex flex-1 flex-col px-6 py-4'>
        <div className='flex flex-wrap items-center justify-between'>
          <div className='flex items-center gap-2'>
            <Input
              showLeftIcon
              showClearIcon
              wrapperClassName='!w-[200px]'
              value={inputValue}
              onChange={e => handleInputChange(e.target.value)}
              onClear={() => handleInputChange('')}
            />
            {/* 状态过滤下拉菜单 */}
            <div className="status-filter-container relative">
              <button
                type="button"
                className="flex h-8 w-32 items-center justify-between rounded-lg border border-components-panel-border bg-components-input-bg-normal px-3 py-1.5 text-sm text-text-secondary shadow-sm hover:bg-state-base-hover focus:outline-none"
                onClick={() => setShowStatusFilter(!showStatusFilter)}
              >
                <span className="truncate">
                  {selectedStatuses.length === 0 ? '过滤状态' : `已选 ${selectedStatuses.length} 项`}
                </span>
                <RiFilterLine className="h-4 w-4" />
              </button>

              {showStatusFilter && (
                <div className="absolute z-10 mt-1 w-48 rounded-md border border-components-panel-border bg-components-panel-bg-blur p-2 shadow-lg backdrop-blur-sm">
                  <div className="mb-2 flex items-center justify-between">
                    <span className="text-xs font-medium text-text-secondary">选择状态</span>
                    <button
                      type="button"
                      onClick={() => setSelectedStatuses([])}
                      className="hover:text-text-accent-hover text-xs text-text-accent"
                    >
                      清除选择
                    </button>
                  </div>
                  {statusOptions.map(option => (
                    <label key={option.value} className="flex cursor-pointer items-center rounded px-2 py-1.5 hover:bg-state-base-hover">
                      <input
                        type="checkbox"
                        checked={selectedStatuses.includes(option.value)}
                        onChange={() => {
                          if (selectedStatuses.includes(option.value))
                            setSelectedStatuses(selectedStatuses.filter(status => status !== option.value))
                           else
                            setSelectedStatuses([...selectedStatuses, option.value])
                        }}
                        className="mr-2 h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                      />
                      <span className="text-sm text-text-secondary">{option.label}</span>
                    </label>
                  ))}
                </div>
              )}
            </div>
          </div>
          <div className='flex !h-8 items-center justify-center gap-2'>
            {!isFreePlan && <AutoDisabledDocument datasetId={datasetId} />}
            <IndexFailed datasetId={datasetId} />
            {!embeddingAvailable && <StatusWithAction type='warning' description={t('dataset.embeddingModelNotAvailable')} />}
            {embeddingAvailable && (
              <Button
                variant='secondary'
                className='shrink-0'
                onClick={handleRetryAll}
                disabled={isRetryingAll}
              >
                <RiRefreshLine className={cn('mr-1 size-4', isRetryingAll && 'animate-spin')} />
                {isRetryingAll ? '恢复中...' : '恢复索引'}
              </Button>
            )}
            {embeddingAvailable && (
              <Button variant='secondary' className='shrink-0' onClick={showEditMetadataModal}>
                <RiDraftLine className='mr-1 size-4' />
                {t('dataset.metadata.metadata')}
              </Button>
            )}
            {isShowEditMetadataModal && (
              <DatasetMetadataDrawer
                userMetadata={datasetMetaData || []}
                onClose={hideEditMetadataModal}
                onAdd={handleAddMetaData}
                onRename={handleRename}
                onRemove={handleDeleteMetaData}
                builtInMetadata={builtInMetaData || []}
                isBuiltInEnabled={!!builtInEnabled}
                onIsBuiltInEnabledChange={setBuiltInEnabled}
              />
            )}
            {embeddingAvailable && (
              <Button variant='primary' onClick={routeToDocCreate} className='shrink-0'>
                <PlusIcon className={cn('mr-2 h-4 w-4 stroke-current')} />
                {isDataSourceNotion && t('datasetDocuments.list.addPages')}
                {isDataSourceWeb && t('datasetDocuments.list.addUrl')}
                {(!dataset?.data_source_type || isDataSourceFile) && t('datasetDocuments.list.addFile')}
              </Button>
            )}
          </div>
        </div>
        {isListLoading
          ? <Loading type='app' />
          : total > 0
            ? <List
              embeddingAvailable={embeddingAvailable}
              documents={documentsList || []}
              datasetId={datasetId}
              onUpdate={handleUpdate}
              selectedIds={selectedIds}
              onSelectedIdChange={setSelectedIds}
              pagination={{
                total,
                limit,
                onLimitChange: setLimit,
                current: currPage,
                onChange: setCurrPage,
              }}
              onManageMetadata={showEditMetadataModal}
            />
            : <EmptyElement canAdd={embeddingAvailable} onClick={routeToDocCreate} type={isDataSourceNotion ? 'sync' : 'upload'} />
        }
        <NotionPageSelectorModal
          isShow={notionPageSelectorModalVisible}
          onClose={() => setNotionPageSelectorModalVisible(false)}
          onSave={handleSaveNotionPageSelected}
          datasetId={dataset?.id || ''}
        />
      </div>
    </div>
  )
}

export default Documents
