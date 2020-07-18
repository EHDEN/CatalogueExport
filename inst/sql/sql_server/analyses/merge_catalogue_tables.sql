{@createTable}?{
  IF OBJECT_ID('@resultsDatabaseSchema.catalogue_@detailType', 'U') IS NOT NULL
    drop table @resultsDatabaseSchema.catalogue_@detailType;
}
--HINT DISTRIBUTE_ON_KEY(analysis_id)
{!@createTable}?{
  insert into @resultsDatabaseSchema.catalogue_@detailType
}
select @fieldNames
{@createTable}?{
  into @resultsDatabaseSchema.catalogue_@detailType
}
from 
(
  @detailSqls
) Q
{@smallCellCount != ''}?{
  where count_value > @smallCellCount
}
;