'use strict'

Application.Controllers.controller "StatisticsController", ["$scope", "$state", "$rootScope", "Statistics", "es", "Member", '_t'
, ($scope, $state, $rootScope, Statistics, es, Member, _t) ->



  ### PUBLIC SCOPE ###

  ## ui-view transitions optimization: if true, the stats will never be refreshed
  $scope.preventRefresh = false

  ## statistics structure in elasticSearch
  $scope.statistics = []

  ## fablab users list
  $scope.members = []

  ## statistics data recovered from elasticSearch
  $scope.data = null

  ## configuration of the widget allowing to pick the ages range
  $scope.agePicker =
    show: false
    start: null
    end: null

  ## total CA for the current view
  $scope.sumCA = 0

  ## average users' age for the current view
  $scope.averageAge = 0

  ## total of the stat field for non simple types
  $scope.sumStat = 0

  ## default: results are not sorted
  $scope.sorting =
    ca: 'none'

  ## active tab will be set here
  $scope.selectedIndex = null

  ## type filter binding
  $scope.type =
    selected: null
    active: null

  ## selected custom filter
  $scope.customFilter =
    show: false
    criterion: {}
    value : null
    exclude: false
    datePicker:
      format: Fablab.uibDateFormat
      opened: false # default: datePicker is not shown
      minDate: null
      maxDate: moment().toDate()
      options:
        startingDay: 1 # France: the week starts on monday

  ## available custom filters
  $scope.filters = []

  ## default: we do not open the datepicker menu
  $scope.datePicker =
    show: false

  ## datePicker parameters for interval beginning
  $scope.datePickerStart =
    format: Fablab.uibDateFormat
    opened: false # default: datePicker is not shown
    minDate: null
    maxDate: moment().subtract(1, 'day').toDate()
    selected: moment().utc().subtract(1, 'months').subtract(1, 'day').startOf('day').toDate()
    options:
      startingDay: Fablab.weekStartingDay

  ## datePicker parameters for interval ending
  $scope.datePickerEnd =
    format: Fablab.uibDateFormat
    opened: false # default: datePicker is not shown
    minDate: null
    maxDate: moment().subtract(1, 'day').toDate()
    selected: moment().subtract(1, 'day').endOf('day').toDate()
    options:
      startingDay: Fablab.weekStartingDay



  ##
  # Callback to open the datepicker (interval start)
  # @param $event {Object} jQuery event object
  ##
  $scope.toggleStartDatePicker = ($event) ->
    toggleDatePicker($event, $scope.datePickerStart)



  ##
  # Callback to open the datepicker (interval end)
  # @param $event {Object} jQuery event object
  ##
  $scope.toggleEndDatePicker = ($event) ->
    toggleDatePicker($event, $scope.datePickerEnd)



  ##
  # Callback to open the datepicker (custom filter)
  # @param $event {Object} jQuery event object
  ##
  $scope.toggleCustomDatePicker = ($event) ->
    toggleDatePicker($event, $scope.customFilter.datePicker)



  ##
  # Callback called when the active tab is changed.
  # recover the current tab and store its value in $scope.selectedIndex
  # @param tab {Object} elasticsearch statistic structure
  ##
  $scope.setActiveTab = (tab) ->
    $scope.selectedIndex = tab
    $scope.type.selected = tab.types[0]
    $scope.type.active = $scope.type.selected
    $scope.customFilter.criterion = {}
    $scope.customFilter.value = null
    $scope.customFilter.exclude = false
    $scope.sorting.ca = 'none'
    buildCustomFiltersList()
    refreshStats()



  ##
  # Callback to validate the filters and send a new request to elastic
  ##
  $scope.validateFilterChange = ->
    $scope.agePicker.show = false
    $scope.customFilter.show = false
    $scope.type.active = $scope.type.selected
    buildCustomFiltersList()
    refreshStats()



  ##
  # Callback to validate the dates range and refresh the data from elastic
  ##
  $scope.validateDateChange = ->
    $scope.datePicker.show = false
    refreshStats()



  ##
  # Parse the given date and return a user-friendly string
  # @param date {Date} JS date or ant moment.js compatible date string
  ##
  $scope.formatDate = (date) ->
    moment(date).format("LL")



  ##
  # Parse the sex and return a user-friendly string
  # @param sex {string} 'male' | 'female'
  ##
  $scope.formatSex = (sex) ->
    if sex == 'male'
      return _t('man')
    if sex == 'female'
      return _t('woman')



  ##
  # Retrieve the label for the given subtype in the current type
  # @param key {string} statistic subtype key
  ##
  $scope.formatSubtype = (key) ->
    label = ""
    angular.forEach $scope.type.active.subtypes, (subtype) ->
      if subtype.key == key
        label = subtype.label
    label



  ##
  # Helper usable in ng-switch to determine the input type to display for custom filter value
  # @param filter {Object} custom filter criterion
  ##
  $scope.getCustomValueInputType = (filter) ->
    if filter and filter.values
      if typeof(filter.values[0]) == 'string'
        return filter.values[0]
      else if typeof(filter.values[0] == 'object')
        return 'input_select'
    else
      'input_text'



  ##
  # Change the sorting order and refresh the results to match the new order
  # @param filter {Object} any filter
  ##
  $scope.toggleSorting = (filter) ->
    switch $scope.sorting[filter]
      when 'none' then $scope.sorting[filter] = 'asc'
      when 'asc' then $scope.sorting[filter] = 'desc'
      when 'desc' then  $scope.sorting[filter] = 'none'
    refreshStats()



  ##
  # Return the user's name from his given ID
  # @param id {number} user ID
  ##
  $scope.getUserNameFromId = (id) ->
    if $scope.members.length == 0
      return "ID "+id
    else
      for member in $scope.members
        if member.id == id
          return member.name
      return "ID "+id



  ### PRIVATE SCOPE ###

  ##
  # Kind of constructor: these actions will be realized first when the controller is loaded
  ##
  initialize = ->
    Statistics.query (stats) ->
      $scope.statistics = stats

    Member.query (members) ->
      $scope.members = members

    # workaround for angular-bootstrap::tabs behavior: on tab deletion, another tab will be selected
    # which will cause every tabs to reload, one by one, when the view is closed
    $rootScope.$on '$stateChangeStart', (event, toState, toParams, fromState, fromParams) ->
      if fromState.name == 'app.admin.statistics' and Object.keys(fromParams).length == 0
        $scope.preventRefresh = true



  ##
  # Generic function to toggle a bootstrap datePicker
  # @param $event {Object} jQuery event object
  # @param datePicker {Object} settings object of the concerned datepicker. Must have an 'opened' property
  ##
  toggleDatePicker = ($event, datePicker) ->
    $event.preventDefault()
    $event.stopPropagation()
    datePicker.opened = !datePicker.opened



  ##
  # Force update the statistics table, querying elasticSearch according to the current config values
  ##
  refreshStats = ->
    if $scope.selectedIndex and !$scope.preventRefresh
      $scope.data = []
      $scope.sumCA = 0
      $scope.averageAge = 0
      $scope.sumStat = 0
      custom = null
      if $scope.customFilter.criterion and $scope.customFilter.criterion.key and $scope.customFilter.value
        custom = {}
        custom.key = $scope.customFilter.criterion.key
        custom.value = $scope.customFilter.value
        custom.exclude = $scope.customFilter.exclude
      queryElasticStats $scope.selectedIndex.es_type_key, $scope.type.active.key, custom, (res, err)->
        if (err)
          console.error("[statisticsController::refreshStats] Unable to refresh due to "+err)
        else
          $scope.data = res.hits
          sumCA = 0
          sumAge = 0
          sumStat = 0
          if $scope.data.length > 0
            angular.forEach $scope.data, (datum) ->
              if datum._source.ca
                sumCA += parseInt(datum._source.ca)
              if datum._source.age
                sumAge += parseInt(datum._source.age)
              if datum._source.stat
                sumStat += parseInt(datum._source.stat)
            sumAge /= $scope.data.length
          $scope.sumCA = sumCA
          $scope.averageAge = Math.round(sumAge*100)/100
          $scope.sumStat = sumStat



  ##
  # Run the elasticSearch query to retreive the /stats/type aggregations
  # @param index {String} elasticSearch document type (account|event|machine|project|subscription|training)
  # @param type {String} statistics type (month|year|booking|hour|user|project)
  # @param custom {{key:{string}, value:{string}}|null} custom filter property or null to disable this filter
  # @param callback {function} function be to run after results were retrieved, it will receive
  #   two parameters : results {Array}, error {String} (if any)
  ##
  queryElasticStats = (index, type, custom, callback) ->
    # handle invalid callback
    if typeof(callback) != "function"
      console.error('[statisticsController::queryElasticStats] Error: invalid callback provided')
      return

    # run query
    es.search
      "index": "stats"
      "type": index
      "size": 1000000000
      "body": buildElasticDataQuery(type, custom, $scope.agePicker.start, $scope.agePicker.end, moment($scope.datePickerStart.selected), moment($scope.datePickerEnd.selected), $scope.sorting)
    , (error, response) ->
      if (error)
        callback([], "Error: something unexpected occurred during elasticSearch query: "+error)
      else
        callback(response.hits)



  ##
  # Build an object representing the content of the REST-JSON query to elasticSearch,
  # based on the provided parameters for row data recovering.
  # @param type {String} statistics type (month|year|booking|hour|user|project)
  # @param custom {{key:{string}, value:{string}}|null} custom filter property or null to disable this filter
  # @param ageMin {Number|null} filter by age: range lower value OR null to do not filter
  # @param ageMax {Number|null} filter by age: range higher value OR null to do not filter
  # @param intervalBegin {moment} statitics interval beginning (moment.js type)
  # @param intervalEnd {moment} statitics interval ending (moment.js type)
  # @param sortings {Array|null} elasticSearch criteria for sorting the results
  ##
  buildElasticDataQuery = (type, custom, ageMin, ageMax, intervalBegin, intervalEnd, sortings) ->
    q =
      "query":
        "bool":
          "must": [
            {
              "term":
                "type": type
            }
            {
              "range":
                "date":
                  "gte": intervalBegin.format()
                  "lte": intervalEnd.format()
            }
          ]
    # optional date range
    if ageMin && ageMax
      q.query.bool.must.push
        "range":
          "age":
            "gte": ageMin
            "lte": ageMax
    # optional criterion
    if custom
      criterion = {
        "match" : {}
      }
      switch $scope.getCustomValueInputType($scope.customFilter.criterion)
        when 'input_date' then criterion.match[custom.key] = moment(custom.value).format('YYYY-MM-DD')
        when 'input_select' then criterion.match[custom.key] = custom.value.key
        when 'input_list' then criterion.match[custom.key+".name"] = custom.value
        else criterion.match[custom.key] = custom.value

      if (custom.exclude)
        q = "query": {
          "filtered": {
            "query": q.query,
            "filter": {
              "not": {
                "term": criterion.match
              }
            }
          }
        }
      else
        q.query.bool.must.push(criterion)


    if sortings
      q["sort"] = buildElasticSortCriteria(sortings)
    q



  ##
  # Parse the provided criteria array and return the corresponding elasticSearch syntax
  # @param criteria {Array} array of {key_to_sort:order}
  ##
  buildElasticSortCriteria = (criteria) ->
    crits = []
    angular.forEach criteria, (value, key) ->
      if typeof value != 'undefined' and value != null and value != 'none'
        c = {}
        c[key] = {'order': value}
        crits.push(c)
    crits



  ##
  # Fullfil the list of available options in the custom filter panel. The list will be based on common
  # properties and on index-specific properties (additional_fields)
  ##
  buildCustomFiltersList = ->
    $scope.filters = []

    filters = [
      {key: 'date', label: _t('date'), values: ['input_date']},
      {key: 'userId', label: _t('user_id'), values: ['input_number']},
      {key: 'gender', label: _t('gender'), values: [{key:'male', label:_t('man')}, {key:'female', label:_t('woman')}]},
      {key: 'age', label: _t('age'), values: ['input_number']},
      {key: 'subType', label: _t('type'), values: $scope.type.active.subtypes},
      {key: 'ca', label: _t('revenue'), values: ['input_number']}
    ]

    $scope.filters = filters

    if !$scope.type.active.simple
      f = {key: 'stat', label: $scope.type.active.label, values: ['input_number']}
      $scope.filters.push(f)

    angular.forEach $scope.selectedIndex.additional_fields, (field) ->
      filter = {key: field.key, label: field.label, values:[]}
      switch field.data_type
        when 'index' then filter.values.push('input_number')
        when 'number' then filter.values.push('input_number')
        when 'date' then filter.values.push('input_date')
        when 'list' then filter.values.push('input_list')
        else filter.values.push('input_text')

      $scope.filters.push(filter)




  # init the controller (call at the end !)
  initialize()

]
